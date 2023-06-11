using Documenter
using QUBOInstances

# Set up to run docstrings with jldoctest
DocMeta.setdocmeta!(QUBOInstances, :DocTestSetup, :(using QUBOInstances); recursive = true)

makedocs(;
    modules = [QUBOInstances],
    doctest = true,
    clean   = true,
    format  = Documenter.HTML(
        assets           = ["assets/extra_styles.css", "assets/favicon.ico"],
        mathengine       = Documenter.KaTeX(),
        sidebar_sitename = false,
    ),
    sitename = "QUBOInstances.jl",
    authors  = "Pedro Maciel Xavier and David E. Bernal Neira",
    pages = [
        "Home" => "index.md",
        "API"  => "api.md",
    ],
    workdir = @__DIR__,
)

if "--skip-deploy" ∈ ARGS
    @warn "Skipping deployment"
else
    deploydocs(repo = raw"github.com/pedromxavier/QUBOInstances.jl.git", push_preview = true)
end
