using Documenter
using DocumenterDiagrams
using DocumenterInterLinks

using QUBOLib

# Set up to run docstrings with jldoctest
DocMeta.setdocmeta!(QUBOLib, :DocTestSetup, :(using QUBOLib); recursive = true)

links = InterLinks(
    "QUBOTools" => "https://juliaqubo.github.io/QUBOTools.jl/dev/objects.inv",
)

makedocs(;
    modules  = [QUBOLib],
    doctest  = true,
    clean    = true,
    warnonly = [:missing_docs],
    format   = Documenter.HTML(
        assets           = ["assets/extra_styles.css", "assets/favicon.ico"],
        mathengine       = Documenter.KaTeX(),
        sidebar_sitename = false,
    ),
    sitename = "QUBOLib.jl",
    authors  = "Pedro Maciel Xavier and David E. Bernal Neira",
    pages    = [
        "Home"     => "index.md",
        "API"      => "api.md",
        "Manual"   => [
            "Introduction"    => "manual/0-intro.md",
            "Basic Usage"     => "manual/1-basic.md",
            "Advanced Usage"  => "manual/2-advanced.md",
        ],
        # "Booklet"  => [
        #     "Introduction"   => "booklet/0-intro.md",
        #     "Library Design" => "booklet/1-design.md",
        # ],
    ],
    plugins  = [links],
    workdir  = @__DIR__,
)

if "--skip-deploy" ∈ ARGS
    @warn "Skipping deployment"
else
    deploydocs(repo = raw"github.com/JuliaQUBO/QUBOLib.jl.git", push_preview = true)
end
