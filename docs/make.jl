push!(LOAD_PATH, joinpath(@__DIR__, ".."))

using Documenter
using TomoPhantom
using Literate

# Generate markdown files from Literate.jl scripts
literate_dir = joinpath(@__DIR__, "literate")
tutorials_dir = joinpath(@__DIR__, "src", "tutorials")

for file in ["2d-phantom.jl", "models.jl", "projections.jl"]
    script_path = joinpath(literate_dir, file)
    if isfile(script_path)
        Literate.markdown(script_path, tutorials_dir; documenter=true)
    end
end

makedocs(
    sitename = "TomoPhantom.jl",
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", nothing) == "true"
    ),
    modules = [TomoPhantom],
    pages = [
        "Home" => "index.md",
        "Introduction" => [
            "About TomoPhantom.jl" => "introduction.md",
            "About TomoPhantom" => "about_tomophantom.md"
        ],
        "Installation Guide" => "installation.md",
        "Tutorials" => [
            "2D Phantom" => "tutorials/2d-phantom.md",
            "Models" => "tutorials/models.md",
            "Projections" => "tutorials/projections.md"
        ],
        "API Reference" => [
            "Core" => "api/core.md",
            "Generators" => "api/generators.md",
            "Projections" => "api/projections.md",
            "Artefacts" => "api/artefacts.md",
            "Quality Metrics" => "api/qualitymetrics.md"
        ]
    ],
)

deploydocs(
    repo = "github.com/hashimoto-koh/TomoPhantom.jl.git",
    devbranch = "master",
    push_preview = true,
)
