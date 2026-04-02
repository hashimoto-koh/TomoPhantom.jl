push!(LOAD_PATH, joinpath(@__DIR__, ".."))

using Documenter
using TomoPhantom

makedocs(
    sitename = "TomoPhantom.jl",
    format = Documenter.HTML(),
    modules = [TomoPhantom],
    pages = [
        "Home" => "index.md",
    ],
)

deploydocs(
    repo = "github.com/hashimoto-koh/TomoPhantom.jl.git",
    devbranch = "main",
    dirname = "julia-docs",
)
