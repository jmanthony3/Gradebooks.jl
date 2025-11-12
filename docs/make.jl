using Gradebooks
using Documenter

DocMeta.setdocmeta!(Gradebooks, :DocTestSetup, :(using Gradebooks); recursive=true)

makedocs(;
    modules=[Gradebooks],
    authors="Joby M. Anthony III",
    sitename="Gradebooks.jl",
    format=Documenter.HTML(;
        canonical="https://jmanthony3.github.io/Gradebooks.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/jmanthony3/Gradebooks.jl",
    devbranch="main",
)
