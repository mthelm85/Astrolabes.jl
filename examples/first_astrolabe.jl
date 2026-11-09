# A complete astrolabe for Zürich, ready to order from a laser-cutting service.
#
#     julia --project=. examples/first_astrolabe.jl

using Astrolabes

a = astrolabe(
    47.3;
    longitude = 8.54,
    timezone = 1.0,
    diameter_mm = 150,
    profile = LaserCut(),
)

report = verify(a)            # geometry, the instrument in use, and fabrication checks
display(report)
Astrolabes.passed(report) || error("verification failed")

println(error_budget(a))      # how fabrication tolerances show up in use (minutes)

dir = joinpath(@__DIR__, "zurich_lasercut")
files = render(a, dir)        # SVG + DXF per part, and parts.txt
println("wrote ", length(files), " files to ", dir)

# use it: sunrise on 21 June, read off the drawn instrument
sim = simulate(a)
r = sunrise(sim, (6, 21))
println("sunrise 21 June: ", round(r.mean; digits = 3), " h CET (equation of time applied)")
