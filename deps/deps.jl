const generated_deps_file = joinpath(@__DIR__, "deps-generated.jl")

if isfile(generated_deps_file)
    include(generated_deps_file)
else
    const libtomophantom = nothing
    const phantom2d_library_path = nothing
    const phantom3d_library_path = nothing
    const upstream_repo = nothing
    const upstream_ref = nothing
end
