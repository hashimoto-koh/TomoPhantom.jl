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

function patch_source!(path, old_snippet, new_snippet; label)
    source = replace(read(path, String), "\r\n" => "\n")
    if occursin(new_snippet, source)
        return false
    end
    if !occursin(old_snippet, source)
        @warn "Skipping local TomoPhantom patch because the expected hunk was not found" file=path label
        return false
    end
    write(path, replace(source, old_snippet => new_snippet))
    return true
end

const PATCH_2D_RECTANGLE_OLD = """
                SS = xwid/CF*C0;
                
                if (fabs(CF) <= (float)EPS) {
                    SS = ywid*C0;
                    if ((P0 - A2) > (float)EPS) {
                        SS=0.0f;
                    }
                }
                if (fabs(SF) <= (float)EPS) {
                    SS = xwid*C0;
                    if ((P0 - B2) > (float)EPS) {
                        SS=0.0f;
                    }
                }
                TF = SF/CF;
"""

const PATCH_2D_RECTANGLE_NEW = """
                if (fabs(CF) <= 1.0e-6f) {
                    SS = ywid*C0;
                    if ((P0 - A2) > (float)EPS) {
                        SS=0.0f;
                    }
                    A[tt*AngTot*P+ j*AngTot+i] += (N/2.0f)*SS;
                    continue;
                }
                if (fabs(SF) <= 1.0e-6f) {
                    SS = xwid*C0;
                    if ((P0 - B2) > (float)EPS) {
                        SS=0.0f;
                    }
                    A[tt*AngTot*P+ j*AngTot+i] += (N/2.0f)*SS;
                    continue;
                }
                SS = xwid/CF*C0;
                TF = SF/CF;
"""

const PATCH_3D_RECTANGLE_OLD = """
                                    SS = xwid/CF*C0;
                                    
                                    if (fabs(CF) <= (float)EPS) {
                                        SS = ywid*C0;
                                        if ((P0 - A2) > (float)EPS) SS=0.0f;
                                    }
                                    if (fabs(SF) <= (float)EPS) {
                                        SS = xwid*C0;
                                        if ((P0 - B2) > (float)EPS) SS=0.0f;
                                    }
                                    
                                    TF = SF/CF;
"""

const PATCH_3D_RECTANGLE_NEW = """
                                    if (fabs(CF) <= 1.0e-6f) {
                                        SS = ywid*C0;
                                        if ((P0 - A2) > (float)EPS) SS=0.0f;
                                        A[index] += (N/2.0f)*SS;
                                        continue;
                                    }
                                    if (fabs(SF) <= 1.0e-6f) {
                                        SS = xwid*C0;
                                        if ((P0 - B2) > (float)EPS) SS=0.0f;
                                        A[index] += (N/2.0f)*SS;
                                        continue;
                                    }
                                    
                                    SS = xwid/CF*C0;
                                    TF = SF/CF;
"""

const PATCH_3D_CONE_DISPATCH_OLD = """
                                if ((strcmp("gaussian",tmpstr2) == 0) || (strcmp("paraboloid",tmpstr2) == 0) || (strcmp("ellipsoid",tmpstr2) == 0)) {
"""

const PATCH_3D_CONE_DISPATCH_NEW = """
                                if ((strcmp("gaussian",tmpstr2) == 0) || (strcmp("paraboloid",tmpstr2) == 0) || (strcmp("ellipsoid",tmpstr2) == 0) || (strcmp("cone",tmpstr2) == 0)) {
"""

const PATCH_3D_CONE_OBJECT_OLD = """
                            if (strcmp("gaussian",Object) == 0) {
                                /* The object is a volumetric gaussian */
                                alh=alog2*a2;
                                bth=alog2*b2;
                                gmh=alog2*c2;
                                
                                a_v = 1.0f/(alh*powf((aa[0]),2) + bth*powf((aa[1]),2) + gmh*powf((aa[2]),2));
                                b_v = aa[0]*alh*(al[0]-xh[0]) + aa[1]*bth*(al[1]-xh[1]) + aa[2]*gmh*(al[2]-xh[2]);
                                c_v = alh*powf(((al[0]-xh[0])),2) + bth*powf(((al[1]-xh[1])),2) + gmh*powf(((al[2]-xh[2])),2);
                                
                                A[index] += multiplier*sqrtf(M_PI*a_v)*expf((pow(b_v,2))*a_v-c_v);
                            }
"""

const PATCH_3D_CONE_OBJECT_NEW = """
                            if (strcmp("cone",Object) == 0) {
                                /* the object is a cone */
                                float cone_min, cone_sqrt_a, cone_half_width, cone_sqrt_term, cone_integral;
                                a_v = powf((aa[0]/a),2) + powf((aa[1]/b),2) + powf((aa[2]/c),2);
                                b_v = aa[0]*(al[0]-xh[0])*a2 + aa[1]*(al[1]-xh[1])*b2 + aa[2]*(al[2]-xh[2])*c2;
                                c_v = powf(((al[0]-xh[0])/a),2) + powf(((al[1]-xh[1])/b), 2) + powf(((al[2]-xh[2])/c),2) - 1.0f;
                                d_v = b_v*b_v - a_v*c_v;
                                
                                if(d_v > 0) {
                                    p1 = -(sqrtf(d_v)+b_v)/a_v;
                                    p2 = (sqrtf(d_v)-b_v)/a_v;
                                    cone_min = 1.0f - d_v/a_v;
                                    if (cone_min < 0.0f) cone_min = 0.0f;
                                    if (cone_min <= 1.0e-7f) {
                                        cone_integral = 0.5f*(p2 - p1);
                                    }
                                    else {
                                        cone_sqrt_a = sqrtf(a_v);
                                        cone_half_width = sqrtf(d_v)/a_v;
                                        cone_sqrt_term = sqrtf(cone_min);
                                        cone_integral = (p2 - p1) - cone_half_width -
                                                        (cone_min/cone_sqrt_a)*asinhf((cone_sqrt_a*cone_half_width)/cone_sqrt_term);
                                    }
                                    A[index] += multiplier*cone_integral;
                                }
                            }
                            if (strcmp("gaussian",Object) == 0) {
                                /* The object is a volumetric gaussian */
                                alh=alog2*a2;
                                bth=alog2*b2;
                                gmh=alog2*c2;
                                
                                a_v = 1.0f/(alh*powf((aa[0]),2) + bth*powf((aa[1]),2) + gmh*powf((aa[2]),2));
                                b_v = aa[0]*alh*(al[0]-xh[0]) + aa[1]*bth*(al[1]-xh[1]) + aa[2]*gmh*(al[2]-xh[2]);
                                c_v = alh*powf(((al[0]-xh[0])),2) + bth*powf(((al[1]-xh[1])),2) + gmh*powf(((al[2]-xh[2])),2);
                                
                                A[index] += multiplier*sqrtf(M_PI*a_v)*expf((pow(b_v,2))*a_v-c_v);
                            }
"""

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

patch_source!(joinpath(upstream_root, "Core", "TomoP2DModelSino_core.c"),
              PATCH_2D_RECTANGLE_OLD, PATCH_2D_RECTANGLE_NEW; label="2d-rectangle-sinogram")
patch_source!(joinpath(upstream_root, "Core", "TomoP3DModelSino_core.c"),
              PATCH_3D_RECTANGLE_OLD, PATCH_3D_RECTANGLE_NEW; label="3d-rectangle-sinogram")
patch_source!(joinpath(upstream_root, "Core", "TomoP3DModelSino_core.c"),
              PATCH_3D_CONE_DISPATCH_OLD, PATCH_3D_CONE_DISPATCH_NEW; label="3d-cone-dispatch")
patch_source!(joinpath(upstream_root, "Core", "TomoP3DModelSino_core.c"),
              PATCH_3D_CONE_OBJECT_OLD, PATCH_3D_CONE_OBJECT_NEW; label="3d-cone-sinogram")

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
