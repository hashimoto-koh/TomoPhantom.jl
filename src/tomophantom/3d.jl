"""
    phantom3d

Yields fully discretized volumetric arrays from specific library geometries.
Returns an `Array{Float32, 3}` for stationary 3D models and an
`Array{Float32, 4}` for temporal 3D models.
"""
function phantom3d(core::NativeCore, model::LibraryModel, n::Int)
    frames = get(_phantom3d_temporal_frames, model.id, nothing)
    A = isnothing(frames) ? zeros(Float32, n, n, n) : zeros(Float32, n, n, n, frames)
    GC.@preserve A begin
        ccall(core.fp_model3d, Cfloat,
              (Ptr{Cfloat}, Cint, Clong, Clong, Clong, Clong, Clong, Cstring),
              A, Cint(model.id), Clong(n), Clong(n), Clong(n), Clong(0), Clong(n), model.dat_path)
    end
    return A
end

"""
    object3d

Rasterizes volumetric parametric definitions supplied via `ObjectSpec3D` evaluating scalar integrations down canonical grid boundaries. Emits a solid `Array{Float32, 3}` structured natively as `[x, y, z]`.
"""
function object3d(core::NativeCore, n::Int, spec::ObjectSpec3D=ObjectSpec3D())
    A = zeros(Float32, n, n, n)
    GC.@preserve A begin
        ccall(core.fp_object3d, Cfloat,
              (Ptr{Cfloat}, Clong, Clong, Clong, Clong, Clong, Cstring,
               Cfloat, Cfloat, Cfloat, Cfloat, Cfloat, Cfloat, Cfloat,
               Cfloat, Cfloat, Cfloat, Clong),
              A, Clong(n), Clong(n), Clong(n), Clong(0), Clong(n), spec.object,
              spec.C0, spec.x0, spec.y0, spec.z0, spec.a, spec.b, spec.c,
              spec.phi1, spec.phi2, spec.phi3, Clong(spec.tt))
    end
    return A
end

function _rand_init3d(
    rng::AbstractRNG,
    x0min::Real,
    x0max::Real,
    y0min::Real,
    y0max::Real,
    z0min::Real,
    z0max::Real,
    c0min::Real,
    c0max::Real,
    ab_min::Real,
    ab_max::Real,
)
    x0 = rand(rng, Float32) * Float32(x0max - x0min) + Float32(x0min)
    y0 = rand(rng, Float32) * Float32(y0max - y0min) + Float32(y0min)
    z0 = rand(rng, Float32) * Float32(z0max - z0min) + Float32(z0min)
    c0 = rand(rng, Float32) * Float32(c0max - c0min) + Float32(c0min)
    ab = rand(rng, Float32) * Float32(ab_max - ab_min) + Float32(ab_min)
    return x0, y0, z0, c0, ab
end

function _foam3d_object_type(rng::AbstractRNG, object_type::AbstractString, mix_objects::Bool)
    if mix_objects
        return rand(rng, ("ellipsoid", "paraboloid", "gaussian"))
    elseif object_type in ("ellipsoid", "paraboloid", "gaussian")
        return String(object_type)
    else
        throw(ArgumentError("object_type must be one of \"ellipsoid\", \"paraboloid\", \"gaussian\", or \"mix\""))
    end
end

"""
    foam3D(...)

Generate a random 3D foam-like phantom using non-overlapping spherical objects.
Returns `(phantom, objects)` where `objects` is a `Vector{ObjectSpec3D}`.
"""
function foam3D(
    x0min::Real,
    x0max::Real,
    y0min::Real,
    y0max::Real,
    z0min::Real,
    z0max::Real,
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
    _foam3d_object_type(rng, object_type, mix_objects)

    x0s = zeros(Float32, tot_objects)
    y0s = zeros(Float32, tot_objects)
    z0s = zeros(Float32, tot_objects)
    abs_ = zeros(Float32, tot_objects)
    c0s = zeros(Float32, tot_objects)

    for i in eachindex(x0s)
        accepted = false
        for _ in 1:attempts
            x0, y0, z0, c0, ab = _rand_init3d(rng, x0min, x0max, y0min, y0max, z0min, z0max, c0min, c0max, ab_min, ab_max)
            inside = (abs(x0) + ab)^2 + (abs(y0) + ab)^2 + (abs(z0) + ab)^2 <= 1.0f0
            separated = all(j -> sqrt((x0s[j] - x0)^2 + (y0s[j] - y0)^2 + (z0s[j] - z0)^2) >= abs_[j] + ab, 1:(i - 1))
            if inside && separated
                x0s[i] = x0
                y0s[i] = y0
                z0s[i] = z0
                abs_[i] = ab
                c0s[i] = c0
                accepted = true
                break
            end
        end
        if !accepted
            x0, y0, z0, c0, _ = _rand_init3d(rng, x0min, x0max, y0min, y0max, z0min, z0max, c0min, c0max, ab_min, ab_max)
            x0s[i] = x0
            y0s[i] = y0
            z0s[i] = z0
            abs_[i] = 0.0001f0
            c0s[i] = c0
        end
    end

    objects = Vector{ObjectSpec3D}(undef, tot_objects)
    phantom = zeros(Float32, n, n, n)
    for i in eachindex(objects)
        spec = ObjectSpec3D(
            object=_foam3d_object_type(rng, object_type, mix_objects),
            C0=c0s[i],
            x0=x0s[i],
            y0=y0s[i],
            z0=z0s[i],
            a=abs_[i],
            b=abs_[i],
            c=abs_[i],
            phi1=0.0f0,
            phi2=0.0f0,
            phi3=0.0f0,
            tt=0,
        )
        objects[i] = spec
        phantom .+= object3d(core, n, spec)
    end
    return phantom, objects
end

"""
    sino3d_natural

Performs pure analytical forward projections over 3D volumetric model configurations. The `z1`, `z2` dimensions natively slice constraints onto the vertical planes. 
Returns dense continuous arrays mapping natively to `S[u, v, angle]` for
stationary models and `S[u, v, angle, t]` for temporal models.
"""
function sino3d_natural(core::NativeCore, model::LibraryModel, geom::SinoGeom3D)
    angles_deg = geom.angles_deg
    ang_tot = length(angles_deg)
    sub_v = geom.z2 - geom.z1
    sub_v > 0 || throw(ArgumentError("z2 must be larger than z1"))
    frames = get(_phantom3d_temporal_frames, model.id, nothing)
    S = isnothing(frames) ? zeros(Float32, geom.detector_u, sub_v, ang_tot) : zeros(Float32, geom.detector_u, sub_v, ang_tot, frames)
    GC.@preserve S angles_deg begin
        ccall(core.fp_modelsino3d, Cfloat,
              (Ptr{Cfloat}, Cint, Clong, Clong, Clong, Clong, Clong, Ptr{Cfloat}, Cint, Cstring),
              S, Cint(model.id), Clong(geom.detector_u), Clong(geom.detector_v), Clong(geom.z1), Clong(geom.z2),
              Clong(geom.phantom_size), angles_deg, Cint(ang_tot), model.dat_path)
    end
    return S
end

"""
    object_sino3d_natural

Extends analytical sinogram projection over user-defined mathematical primitive bounds defined statically inside `ObjectSpec3D` structs. Returns `S[u, v, angle]`.
"""
function object_sino3d_natural(core::NativeCore, geom::SinoGeom3D, spec::ObjectSpec3D=ObjectSpec3D())
    angles_deg = geom.angles_deg
    ang_tot = length(angles_deg)
    sub_v = geom.z2 - geom.z1
    sub_v > 0 || throw(ArgumentError("z2 must be larger than z1"))
    S = zeros(Float32, geom.detector_u, sub_v, ang_tot)
    GC.@preserve S angles_deg begin
        ccall(core.fp_objectsino3d, Cfloat,
              (Ptr{Cfloat}, Clong, Clong, Clong, Clong, Clong, Ptr{Cfloat}, Cint, Cstring,
               Cfloat, Cfloat, Cfloat, Cfloat, Cfloat, Cfloat, Cfloat,
               Cfloat, Cfloat, Cfloat, Clong),
              S, Clong(geom.detector_u), Clong(geom.detector_v), Clong(geom.z1), Clong(geom.z2),
              Clong(geom.phantom_size), angles_deg, Cint(ang_tot), spec.object,
              spec.C0, spec.x0, spec.y0, spec.z0, spec.a, spec.b, spec.c,
              spec.phi1, spec.phi2, spec.phi3, Clong(spec.tt))
    end
    return S
end

"""
    sino3d_u_angle_v_view

Zero-overhead dimension permutation translating canonical volumetric sinogram arrays bounded `[u, v, angle]` out to standard algorithm frameworks expecting `[u, angle, v]` boundaries.
"""
sino3d_u_angle_v_view(S_u_v_angle::Array{Float32,3}) = PermutedDimsArray(S_u_v_angle, (1, 3, 2))
