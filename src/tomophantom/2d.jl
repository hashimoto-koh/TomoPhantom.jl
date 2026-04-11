"""
    phantom2d

Computes a spatial 2D discrete rendering (matrix slice) from an explicitly identified analytical library model instance.

**Arguments**:
- `core::NativeCore`: The initialized Native C binding context.
- `model::LibraryModel`: The model specification ID bounded to `.dat` location.
- `n::Int`: Expected discrete lattice scale `[N x N]`.

Returns an `Array{Float32, 2}` for stationary 2D models and an
`Array{Float32, 3}` for temporal 2D models.
"""
function phantom2d(core::NativeCore, model::LibraryModel, n::Int)
    frames = get(_phantom2d_temporal_frames, model.id, nothing)
    A = isnothing(frames) ? zeros(Float32, n, n) : zeros(Float32, n, n, frames)
    GC.@preserve A begin
        ccall(core.fp_model2d, Cfloat, (Ptr{Cfloat}, Cint, Cint, Cstring), A, Cint(model.id), Cint(n), model.dat_path)
    end
    return A
end

"""
    object2d

Renders natively an unguided `ObjectSpec2D` mapping mathematically onto a discrete Cartesian lattice array `[N x N]`. Emits an `Array{Float32, 2}`.
"""
function object2d(core::NativeCore, n::Int, spec::ObjectSpec2D=ObjectSpec2D())
    A = zeros(Float32, n, n)
    GC.@preserve A begin
        ccall(core.fp_object2d, Cfloat,
              (Ptr{Cfloat}, Cint, Cstring, Cfloat, Cfloat, Cfloat, Cfloat, Cfloat, Cfloat, Cint),
              A, Cint(n), spec.object, spec.C0, spec.x0, spec.y0, spec.a, spec.b, spec.phi_rot, Cint(spec.tt))
    end
    return A
end

function _rand_init2d(
    rng::AbstractRNG,
    x0min::Real,
    x0max::Real,
    y0min::Real,
    y0max::Real,
    c0min::Real,
    c0max::Real,
    ab_min::Real,
    ab_max::Real,
)
    x0 = rand(rng, Float32) * Float32(x0max - x0min) + Float32(x0min)
    y0 = rand(rng, Float32) * Float32(y0max - y0min) + Float32(y0min)
    c0 = rand(rng, Float32) * Float32(c0max - c0min) + Float32(c0min)
    ab = rand(rng, Float32) * Float32(ab_max - ab_min) + Float32(ab_min)
    return x0, y0, c0, ab
end

function _foam2d_object_type(rng::AbstractRNG, object_type::AbstractString, mix_objects::Bool)
    if mix_objects
        return rand(rng, ("ellipse", "parabola", "gaussian"))
    elseif object_type in ("ellipse", "parabola", "gaussian")
        return String(object_type)
    else
        throw(ArgumentError("object_type must be one of \"ellipse\", \"parabola\", \"gaussian\", or \"mix\""))
    end
end

"""
    foam2D(...)

Generate a random 2D foam-like phantom using non-overlapping circular objects.
Returns `(phantom, objects)` where `objects` is a `Vector{ObjectSpec2D}`.
"""
function foam2D(
    x0min::Real,
    x0max::Real,
    y0min::Real,
    y0max::Real,
    c0min::Real,
    c0max::Real,
    ab_min::Real,
    ab_max::Real,
    n::Int,
    tot_objects::Int,
    object_type::AbstractString;
    core::NativeCore=NativeCore(),
    rng::AbstractRNG=Random.default_rng(),
)
    attempts = 2000
    tot_objects > 0 || throw(ArgumentError("tot_objects must be positive"))
    mix_objects = object_type == "mix"
    _foam2d_object_type(rng, object_type, mix_objects)

    x0s = zeros(Float32, tot_objects)
    y0s = zeros(Float32, tot_objects)
    abs_ = zeros(Float32, tot_objects)
    c0s = zeros(Float32, tot_objects)

    for i in eachindex(x0s)
        accepted = false
        for _ in 1:attempts
            x0, y0, c0, ab = _rand_init2d(rng, x0min, x0max, y0min, y0max, c0min, c0max, ab_min, ab_max)
            inside = (abs(x0) + ab)^2 + (abs(y0) + ab)^2 <= 1.0f0
            separated = all(j -> hypot(x0s[j] - x0, y0s[j] - y0) >= abs_[j] + ab, 1:(i - 1))
            if inside && separated
                x0s[i] = x0
                y0s[i] = y0
                abs_[i] = ab
                c0s[i] = c0
                accepted = true
                break
            end
        end
        if !accepted
            x0, y0, c0, _ = _rand_init2d(rng, x0min, x0max, y0min, y0max, c0min, c0max, ab_min, ab_max)
            x0s[i] = x0
            y0s[i] = y0
            abs_[i] = 0.0001f0
            c0s[i] = c0
        end
    end

    objects = Vector{ObjectSpec2D}(undef, tot_objects)
    phantom = zeros(Float32, n, n)
    for i in eachindex(objects)
        spec = ObjectSpec2D(
            object=_foam2d_object_type(rng, object_type, mix_objects),
            C0=c0s[i],
            x0=x0s[i],
            y0=y0s[i],
            a=abs_[i],
            b=abs_[i],
            phi_rot=0.0f0,
            tt=0,
        )
        objects[i] = spec
        phantom .+= object2d(core, n, spec)
    end
    return phantom, objects
end

"""
    sino2d_natural

Executes purely analytical path-integral tomographic forward projection over an identified 2D library model.

Produces native C-ordered representations scaling explicitly to `S[angle, u]`
for stationary models and `S[angle, u, t]` for temporal models.
"""
function sino2d_natural(core::NativeCore, model::LibraryModel, geom::SinoGeom2D; centype::Int=0)
    angles_deg = geom.angles_deg
    ang_tot = length(angles_deg)
    frames = get(_phantom2d_temporal_frames, model.id, nothing)
    S = isnothing(frames) ? zeros(Float32, ang_tot, geom.detector_u) : zeros(Float32, ang_tot, geom.detector_u, frames)
    GC.@preserve S angles_deg begin
        ccall(core.fp_modelsino2d, Cfloat,
              (Ptr{Cfloat}, Cint, Cint, Cint, Ptr{Cfloat}, Cint, Cint, Cstring),
              S, Cint(model.id), Cint(geom.phantom_size), Cint(geom.detector_u), angles_deg,
              Cint(ang_tot), Cint(centype), model.dat_path)
    end
    return S
end

"""
    object_sino2d_natural

Calculates analytical sinograms mapped heavily upon individual `ObjectSpec2D` shape primitives mapped canonically into continuous space boundaries. Emits an `Array{Float32, 2}` structured `[angle, u]`.
"""
function object_sino2d_natural(core::NativeCore, geom::SinoGeom2D, spec::ObjectSpec2D=ObjectSpec2D(); centype::Int=0)
    angles_deg = geom.angles_deg
    ang_tot = length(angles_deg)
    S = zeros(Float32, ang_tot, geom.detector_u)
    GC.@preserve S angles_deg begin
        ccall(core.fp_objectsino2d, Cfloat,
              (Ptr{Cfloat}, Cint, Cint, Ptr{Cfloat}, Cint, Cint, Cstring, Cfloat, Cfloat, Cfloat, Cfloat, Cfloat, Cfloat, Cint),
              S, Cint(geom.phantom_size), Cint(geom.detector_u), angles_deg, Cint(ang_tot), Cint(centype),
              spec.object, spec.C0, spec.x0, spec.y0, spec.a, spec.b, spec.phi_rot, Cint(spec.tt))
    end
    return S
end

"""
    sino2d_u_angle_view

Zero-overhead transpose wrapper mutating canonical 2D sinogram matrices `[angle, u]` perfectly onto `[u, angle]` to seamlessly attach to general reconstruction toolkits (like ASTRA/ODL).
"""
sino2d_u_angle_view(S_angle_u::AbstractMatrix{<:Real}) = transpose(S_angle_u)
