using Downloads
using Libdl

pkg_root = normpath(joinpath(@__DIR__, ".."))
build_dir = joinpath(@__DIR__, "build")
prefix_dir = joinpath(@__DIR__, "usr")
lib_dir = Sys.iswindows() ? joinpath(prefix_dir, "bin") : joinpath(prefix_dir, "lib")
upstream_root = joinpath(@__DIR__, "upstream-src")

mkpath(build_dir)
mkpath(prefix_dir)
mkpath(upstream_root)

const DEFAULT_UPSTREAM_REPO = "dkazanc/TomoPhantom"
const DEFAULT_UPSTREAM_REF = "b75287a9706750951f8194902346ad91f7129064"

function require_cmd(cmd)
    path = Sys.which(cmd)
    path === nothing && error("`$(cmd)` was not found in PATH. Install it before building TomoPhantom.jl.")
    return path
end

function env_or_default(name, default)
    value = get(ENV, name, default)
    isempty(value) && return default
    return value
end

function raw_url(repo, ref, relative_path)
    return "https://raw.githubusercontent.com/$(repo)/$(ref)/$(relative_path)"
end

function fetch_file!(repo, ref, relative_path)
    destination = joinpath(upstream_root, splitpath(relative_path)...)
    mkpath(dirname(destination))
    Downloads.download(raw_url(repo, ref, relative_path), destination)
    return destination
end

upstream_repo_name = env_or_default("TOMOPHANTOM_UPSTREAM_REPO", DEFAULT_UPSTREAM_REPO)
upstream_ref_name = env_or_default("TOMOPHANTOM_UPSTREAM_REF", DEFAULT_UPSTREAM_REF)

cmake = require_cmd("cmake")

core_files = [
    "CMakeLists.txt",
    "Core/CMakeLists.txt",
    "Core/CCPiDefines.h",
    "Core/TomoP2DModel_core.c",
    "Core/TomoP2DModel_core.h",
    "Core/TomoP2DModelSino_core.c",
    "Core/TomoP2DModelSino_core.h",
    "Core/TomoP2DSinoNum_core.c",
    "Core/TomoP2DSinoNum_core.h",
    "Core/TomoP3DModel_core.c",
    "Core/TomoP3DModel_core.h",
    "Core/TomoP3DModelSino_core.c",
    "Core/TomoP3DModelSino_core.h",
    "Core/utils.c",
    "Core/utils.h",
    "tomophantom/phantomlib/Phantom2DLibrary.dat",
    "tomophantom/phantomlib/Phantom3DLibrary.dat",
]

for relative_path in core_files
    fetch_file!(upstream_repo_name, upstream_ref_name, relative_path)
end

run(`$cmake -S $upstream_root -B $build_dir -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$prefix_dir -DBUILD_PYTHON_WRAPPER=OFF -DBUILD_MATLAB_WRAPPER=OFF`)
run(`$cmake --build $build_dir --config Release`)
run(`$cmake --install $build_dir --config Release`)

libname = Sys.iswindows() ? "tomophantom.dll" : Sys.isapple() ? "libtomophantom.dylib" : "libtomophantom.so"
libpath = joinpath(lib_dir, libname)
isfile(libpath) || error("Built library was not found at $(libpath)")

phantom2d_path = joinpath(upstream_root, "tomophantom", "phantomlib", "Phantom2DLibrary.dat")
phantom3d_path = joinpath(upstream_root, "tomophantom", "phantomlib", "Phantom3DLibrary.dat")

deps_file = joinpath(@__DIR__, "deps-generated.jl")
open(deps_file, "w") do io
    println(io, "const libtomophantom = ", repr(libpath))
    println(io, "const phantom2d_library_path = ", repr(phantom2d_path))
    println(io, "const phantom3d_library_path = ", repr(phantom3d_path))
    println(io, "const upstream_repo = ", repr(upstream_repo_name))
    println(io, "const upstream_ref = ", repr(upstream_ref_name))
end

println("TomoPhantom.jl build complete: ", libpath)
println("Fetched upstream source from ", upstream_repo_name, " @ ", upstream_ref_name)
