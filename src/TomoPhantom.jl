module TomoPhantom

using Libdl

export NativeCore, LibraryModel, SinoGeom2D, SinoGeom3D,
       ObjectSpec2D, ObjectSpec3D,
       default_2d_library_path, default_3d_library_path,
       find_tomophantom_library,
       phantom2d, object2d, sino2d_natural, object_sino2d_natural,
       phantom3d, object3d, sino3d_natural, object_sino3d_natural,
       sino2d_u_angle_view, sino3d_u_angle_v_view,
       demo_step2, selfcheck_step2

include(joinpath(@__DIR__, "..", "deps", "deps.jl"))

"""
    NativeCore

Provides a robust binding context holding function pointers for the natively compiled TomoPhantom C core library. Instantiated implicitly by default during core routine calls, avoiding constant `dlopen` overhead.
"""
struct NativeCore
    lib::Ptr{Cvoid}
    fp_model2d::Ptr{Cvoid}
    fp_modelsino2d::Ptr{Cvoid}
    fp_object2d::Ptr{Cvoid}
    fp_objectsino2d::Ptr{Cvoid}
    fp_model3d::Ptr{Cvoid}
    fp_modelsino3d::Ptr{Cvoid}
    fp_object3d::Ptr{Cvoid}
    fp_objectsino3d::Ptr{Cvoid}
end

"""
    LibraryModel

Maps directly to a precomputed `.dat` phantom library matrix file.

**Fields**:
- `id::Int`: The discrete model identifier index.
- `dat_path::String`: The absolute path where the library file resides.
"""
struct LibraryModel
    id::Int
    dat_path::String
end

"""
    SinoGeom2D

Maintains geometric specifications for generating a 2D line-integral sinogram projection via parallel beam pathways.

**Fields**:
- `phantom_size::Int`: Matrix density of the continuous geometric bounds.
- `detector_u::Int`: The lateral resolution mapped uniformly across the detector array.
- `angles_deg::Vector{Float32}`: Array of tracking angles swept by the path projector.
"""
struct SinoGeom2D
    phantom_size::Int
    detector_u::Int
    angles_deg::Vector{Float32}
end

"""
    SinoGeom3D

Maintains fully volumetric geometric specifications for evaluating 3D planar-integral projections.

**Fields**:
- `phantom_size::Int`: Equivalent volumetric resolution mapped to `[N, N, N]` space.
- `detector_u::Int`, `detector_v::Int`: Dimensions of the planar 2D detector array.
- `z1::Int`, `z2::Int`: Specific volumetric slice boundaries to constrain integrations over.
"""
struct SinoGeom3D
    phantom_size::Int
    detector_u::Int
    detector_v::Int
    angles_deg::Vector{Float32}
    z1::Int
    z2::Int
end

"""
    ObjectSpec2D

A parametric dictionary bounding a generic continuous 2D mathematical object prior to projection.

**Fields**:
- `object::String`: Descriptor matching primitive types (e.g. "gaussian", "rectangle").
- `C0::Float32`: Overall baseline focal intensity/absorption.
- `x0::Float32`, `y0::Float32`: Displacement coordinates scaling globally within `[-1.0, 1.0]` bounds.
- `a::Float32`, `b::Float32`: Asymmetrical axis widths stretching the core geometry.
- `phi_rot::Float32`: Positional rotation spanning in degrees.
- `tt::Int`: Sub-iteration threshold for temporal objects (4D).
"""
struct ObjectSpec2D
    object::String
    C0::Float32
    x0::Float32
    y0::Float32
    a::Float32
    b::Float32
    phi_rot::Float32
    tt::Int
end

ObjectSpec2D(; object::AbstractString="gaussian",
               C0::Float32=1.0f0,
               x0::Float32=0.0f0,
               y0::Float32=0.0f0,
               a::Float32=0.2f0,
               b::Float32=0.2f0,
               phi_rot::Float32=0.0f0,
               tt::Int=0) = ObjectSpec2D(String(object), C0, x0, y0, a, b, phi_rot, tt)

"""
    ObjectSpec3D

A volumetric parametric definition defining geometric primitives in 3D tomographic space prior to rasterization or analytical projection.
Extends the canonical fields of `ObjectSpec2D` by enforcing orthogonal `z0`, `c` modifiers and triplet Euler angle boundaries (`phi1, phi2, phi3`).
"""
struct ObjectSpec3D
    object::String
    C0::Float32
    x0::Float32
    y0::Float32
    z0::Float32
    a::Float32
    b::Float32
    c::Float32
    phi1::Float32
    phi2::Float32
    phi3::Float32
    tt::Int
end

ObjectSpec3D(; object::AbstractString="ellipsoid",
               C0::Float32=1.0f0,
               x0::Float32=0.0f0,
               y0::Float32=0.0f0,
               z0::Float32=0.0f0,
               a::Float32=0.3f0,
               b::Float32=0.2f0,
               c::Float32=0.2f0,
               phi1::Float32=0.0f0,
               phi2::Float32=0.0f0,
               phi3::Float32=0.0f0,
               tt::Int=0) = ObjectSpec3D(String(object), C0, x0, y0, z0, a, b, c, phi1, phi2, phi3, tt)

const _pkg_root = normpath(joinpath(@__DIR__, ".."))

"""
    default_2d_library_path

Resolves globally the exact installation path of `Phantom2DLibrary.dat` shipped natively via the build compilation script dependency.
"""
function default_2d_library_path()
    path = phantom2d_library_path
    isfile(path) || error("2D model library file was not found at $(path)")
    return path
end

"""
    default_3d_library_path

Resolves globally the exact installation path of `Phantom3DLibrary.dat` shipped natively via the build compilation script dependency.
"""
function default_3d_library_path()
    path = phantom3d_library_path
    isfile(path) || error("3D model library file was not found at $(path)")
    return path
end

"""
    find_tomophantom_library

Identifies the actively built execution path of `libtomophantom.so` or equivalents. Throws an explicit error directing `Pkg.build` if unavailable.
"""
function find_tomophantom_library()
    if @isdefined(libtomophantom) && libtomophantom !== nothing
        return libtomophantom
    end

    found = Libdl.find_library(["tomophantom"])
    !isempty(found) && return found
    error("libtomophantom was not found. Run Pkg.build(\"TomoPhantom\") or make the library discoverable.")
end

function NativeCore(libpath::AbstractString=find_tomophantom_library())
    lib = Libdl.dlopen(libpath)
    return NativeCore(
        lib,
        Libdl.dlsym(lib, :TomoP2DModel_core),
        Libdl.dlsym(lib, :TomoP2DModelSino_core),
        Libdl.dlsym(lib, :TomoP2DObject_core),
        Libdl.dlsym(lib, :TomoP2DObjectSino_core),
        Libdl.dlsym(lib, :TomoP3DModel_core),
        Libdl.dlsym(lib, :TomoP3DModelSino_core),
        Libdl.dlsym(lib, :TomoP3DObject_core),
        Libdl.dlsym(lib, :TomoP3DObjectSino_core),
    )
end

"""
    phantom2d

Computes a spatial 2D discrete rendering (matrix slice) from an explicitly identified analytical library model instance.

**Arguments**:
- `core::NativeCore`: The initialized Native C binding context.
- `model::LibraryModel`: The model specification ID bounded to `.dat` location.
- `n::Int`: Expected discrete lattice scale `[N x N]`.

Returns an `Array{Float32, 2}`.
"""
function phantom2d(core::NativeCore, model::LibraryModel, n::Int)
    A = zeros(Float32, n, n)
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

"""
    sino2d_natural

Executes purely analytical path-integral tomographic forward projection over an identified 2D library model.

Produces native C-ordered representations scaling explicitly to `S[angle, u]`. This avoids interpolation and sub-gridding anomalies tied tightly onto pixel bounds.
"""
function sino2d_natural(core::NativeCore, model::LibraryModel, geom::SinoGeom2D; centype::Int=0)
    angles_deg = geom.angles_deg
    ang_tot = length(angles_deg)
    S = zeros(Float32, ang_tot, geom.detector_u)
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
    phantom3d

Yields fully discretized volumetric arrays from specific library geometries. Result maps perfectly to `A[x, y, z]` dimensions dictated by the grid scalar `n`. Creates an `Array{Float32, 3}`.
"""
function phantom3d(core::NativeCore, model::LibraryModel, n::Int)
    A = zeros(Float32, n, n, n)
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

"""
    sino3d_natural

Performs pure analytical forward projections over 3D volumetric model configurations. The `z1`, `z2` dimensions natively slice constraints onto the vertical planes. 
Returns dense continuous matrices mapping natively to `S[u, v, angle]` out of the integration step.
"""
function sino3d_natural(core::NativeCore, model::LibraryModel, geom::SinoGeom3D)
    angles_deg = geom.angles_deg
    ang_tot = length(angles_deg)
    sub_v = geom.z2 - geom.z1
    sub_v > 0 || throw(ArgumentError("z2 must be larger than z1"))
    S = zeros(Float32, geom.detector_u, sub_v, ang_tot)
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
    sino2d_u_angle_view

Zero-overhead transpose wrapper mutating canonical 2D sinogram matrices `[angle, u]` perfectly onto `[u, angle]` to seamlessly attach to general reconstruction toolkits (like ASTRA/ODL).
"""
sino2d_u_angle_view(S_angle_u::AbstractMatrix{<:Real}) = transpose(S_angle_u)
"""
    sino3d_u_angle_v_view

Zero-overhead dimension permutation translating canonical volumetric sinogram arrays bounded `[u, v, angle]` out to standard algorithm frameworks expecting `[u, angle, v]` boundaries.
"""
sino3d_u_angle_v_view(S_u_v_angle::Array{Float32,3}) = PermutedDimsArray(S_u_v_angle, (1, 3, 2))

_has_nonzero(A) = any(!iszero, A)

function _stats(A)
    vmax, imax = findmax(A)
    return (size=size(A), max=vmax, argmax=imax, nonzero=count(!iszero, A))
end

function demo_step2(; libpath::AbstractString=find_tomophantom_library())
    core = NativeCore(libpath)
    model2d = LibraryModel(1, default_2d_library_path())
    model3d = LibraryModel(1, default_3d_library_path())
    geom2d = SinoGeom2D(64, 91, collect(Float32, range(0.0f0, 177.0f0; length=60)))
    geom3d = SinoGeom3D(64, 96, 64, collect(Float32, range(0.0f0, 177.0f0; length=45)), 0, 64)

    A2_model = phantom2d(core, model2d, 64)
    A2_obj = object2d(core, 64, ObjectSpec2D(object="gaussian", x0=0.25f0, y0=-0.3f0, a=0.15f0, b=0.3f0, phi_rot=-30.0f0))
    S2 = sino2d_natural(core, model2d, geom2d)
    S2_obj = object_sino2d_natural(core, geom2d, ObjectSpec2D(object="gaussian", x0=0.1f0, y0=-0.1f0, a=0.2f0, b=0.2f0))
    A3_model = phantom3d(core, model3d, 32)
    A3_obj = object3d(core, 32, ObjectSpec3D(object="ellipsoid", a=0.3f0, b=0.2f0, c=0.2f0))
    S3 = sino3d_natural(core, model3d, geom3d)
    S3_obj = object_sino3d_natural(core, geom3d, ObjectSpec3D(object="ellipsoid", a=0.3f0, b=0.2f0, c=0.2f0))

    checks = (
        phantom2d_nonzero = _has_nonzero(A2_model),
        object2d_nonzero = _has_nonzero(A2_obj),
        sino2d_nonzero = _has_nonzero(S2),
        object_sino2d_nonzero = _has_nonzero(S2_obj),
        phantom3d_nonzero = _has_nonzero(A3_model),
        object3d_nonzero = _has_nonzero(A3_obj),
        sino3d_nonzero = _has_nonzero(S3),
        object_sino3d_nonzero = _has_nonzero(S3_obj),
    )
    all(values(checks)) || error("demo_step2 failed one or more non-zero checks: $(checks)")

    return (
        checks = checks,
        shapes = (
            phantom2d = size(A2_model),
            object2d = size(A2_obj),
            sino2d_natural = size(S2),
            object_sino2d_natural = size(S2_obj),
            phantom3d = size(A3_model),
            object3d = size(A3_obj),
            sino3d_natural = size(S3),
            object_sino3d_natural = size(S3_obj),
            sino2d_u_angle_view = size(sino2d_u_angle_view(S2)),
            sino3d_u_angle_v_view = size(sino3d_u_angle_v_view(S3)),
        ),
        maxima = (
            phantom2d = maximum(A2_model),
            object2d = maximum(A2_obj),
            sino2d = maximum(S2),
            object_sino2d = maximum(S2_obj),
            phantom3d = maximum(A3_model),
            object3d = maximum(A3_obj),
            sino3d = maximum(S3),
            object_sino3d = maximum(S3_obj),
        ),
        stats = (
            phantom2d = _stats(A2_model),
            object2d = _stats(A2_obj),
            sino2d_natural = _stats(S2),
            object_sino2d_natural = _stats(S2_obj),
            phantom3d = _stats(A3_model),
            object3d = _stats(A3_obj),
            sino3d_natural = _stats(S3),
            object_sino3d_natural = _stats(S3_obj),
        ),
    )
end

function selfcheck_step2(; libpath::AbstractString=find_tomophantom_library())
    result = demo_step2(; libpath=libpath)
    @assert all(values(result.checks))
    @assert result.shapes.phantom2d == (64, 64)
    @assert result.shapes.object2d == (64, 64)
    @assert result.shapes.sino2d_natural == (60, 91)
    @assert result.shapes.object_sino2d_natural == (60, 91)
    @assert result.shapes.phantom3d == (32, 32, 32)
    @assert result.shapes.object3d == (32, 32, 32)
    @assert result.shapes.sino3d_natural == (96, 64, 45)
    @assert result.shapes.object_sino3d_natural == (96, 64, 45)
    @assert result.shapes.sino2d_u_angle_view == (91, 60)
    @assert result.shapes.sino3d_u_angle_v_view == (96, 45, 64)
    @assert result.stats.phantom2d.nonzero > 0
    @assert result.stats.object2d.nonzero > 0
    @assert result.stats.sino2d_natural.nonzero > 0
    @assert result.stats.object_sino2d_natural.nonzero > 0
    @assert result.stats.phantom3d.nonzero > 0
    @assert result.stats.object3d.nonzero > 0
    @assert result.stats.sino3d_natural.nonzero > 0
    @assert result.stats.object_sino3d_natural.nonzero > 0
    return result
end

end
