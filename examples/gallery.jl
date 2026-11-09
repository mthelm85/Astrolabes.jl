# Build, verify and preview the gallery instruments.
#
#     julia --project=. examples/gallery.jl
#
# Each instrument must pass `verify` (geometry, use and fabrication checks) before its
# preview is written to docs/src/assets/gallery.

using Astrolabes

const OUT = joinpath(@__DIR__, "..", "docs", "src", "assets", "gallery")
mkpath(OUT)

const GALLERY = [
    ("equator", "Equator (0°)", (0.0,), (;)),
    ("tropic", "Tropic of Cancer (23.4°N)", (23.4,), (;)),
    (
        "zurich",
        "Zürich (47.3°N), hour scale in CET",
        (47.3,),
        (; longitude = 8.54, timezone = 1.0),
    ),
    ("london", "London (51.5°N), brass", (51.5,), (; profile = Metal())),
    ("arctic", "Arctic Circle (66°N)", (66.0,), (;)),
    ("sydney", "Sydney (33.9°S)", (-33.9,), (;)),
    (
        "chaucer",
        "Oxford 1391 (51.75°N), after Chaucer's Treatise",
        (51.75,),
        (; epoch = 1391.0, calendar = :eccentric, names = :traditional),
    ),
]

for (slug, title, args, kw) in GALLERY
    a = astrolabe(args...; kw...)
    rep = verify(a)
    if !Astrolabes.passed(rep)
        display(rep)
        error("$title failed verification")
    end
    render_preview(a, joinpath(OUT, slug * ".svg"))
    println(rpad(title, 52), " ", length(rep.checks), " checks passed")
end
