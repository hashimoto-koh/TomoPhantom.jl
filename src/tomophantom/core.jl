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

const _pkg_root = normpath(joinpath(@__DIR__, "..", ".."))
const _phantom2d_temporal_frames = Dict(
    100 => 3,
    101 => 350,
    102 => 25,
)
const _phantom3d_temporal_frames = Dict(
    100 => 5,
    101 => 10,
    102 => 10,
)

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
