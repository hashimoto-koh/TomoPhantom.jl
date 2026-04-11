module TomoPhantom

using FFTW
using Libdl
using Random

export NativeCore, LibraryModel, SinoGeom2D, SinoGeom3D,
       ObjectSpec2D, ObjectSpec3D,
       default_2d_library_path, default_3d_library_path,
       find_tomophantom_library,
       phantom2d, object2d, foam2D, sino2d_natural, object_sino2d_natural,
       phantom3d, object3d, foam3D, sino3d_natural, object_sino3d_natural,
       artefacts_mix, stripes, zingers, noise, datashifts, datashifts_subpixel,
       pve, fresnel_propagator,
       QualityTools, nrmse, rmse, ssim,
       sino2d_u_angle_view, sino3d_u_angle_v_view,
       demo_step2, selfcheck_step2

include(joinpath(@__DIR__, "..", "deps", "deps.jl"))

include(joinpath(@__DIR__, "tomophantom", "core.jl"))
include(joinpath(@__DIR__, "tomophantom", "2d.jl"))
include(joinpath(@__DIR__, "tomophantom", "3d.jl"))
include(joinpath(@__DIR__, "tomophantom", "artefacts.jl"))
include(joinpath(@__DIR__, "tomophantom", "qualitymetrics.jl"))
include(joinpath(@__DIR__, "tomophantom", "check.jl"))

end
