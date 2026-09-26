push!(LOAD_PATH, joinpath(@__DIR__, ".."))

using Documenter
using TomoPhantom
using Literate

# Generate markdown files from Literate.jl scripts
literate_dir = joinpath(@__DIR__, "literate")
tutorials_dir = joinpath(@__DIR__, "src", "tutorials")
rm(tutorials_dir; recursive=true, force=true)
mkpath(tutorials_dir)

for file in ["2d-phantom.jl", "3d-phantom.jl", "flat-fields.jl", "temporal-4d.jl"]
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
            "2D Phantoms & Sinograms" => "tutorials/2d-phantom.md",
            "3D Phantoms & Projections" => "tutorials/3d-phantom.md",
            "Flat-field Synthesis" => "tutorials/flat-fields.md",
            "Temporal (4D) Phantoms" => "tutorials/temporal-4d.md"
        ],
        "API Reference" => [
            "Core" => "api/core.md",
            "Generators" => "api/generators.md",
            "Projections" => "api/projections.md",
            "Artefacts" => "api/artefacts.md",
            "Flat-field Synthesis" => "api/flatsgen.md",
            "Quality Metrics" => "api/qualitymetrics.md"
        ]
    ],
)

deploydocs(
    repo = "github.com/hashimoto-koh/TomoPhantom.jl.git",
    devbranch = "master",
    push_preview = true,
)
