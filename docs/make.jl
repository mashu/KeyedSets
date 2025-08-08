using KeyedSets
using Documenter

DocMeta.setdocmeta!(KeyedSets, :DocTestSetup, :(using KeyedSets); recursive=true)

makedocs(;
    modules=[KeyedSets],
    authors="Mateusz Kaduk <mateusz.kaduk@gmail.com> and contributors",
    sitename="KeyedSets.jl",
    format=Documenter.HTML(;
        canonical="https://mashu.github.io/KeyedSets.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/mashu/KeyedSets.jl",
    devbranch="main",
)
