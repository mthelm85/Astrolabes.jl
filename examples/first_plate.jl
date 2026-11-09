# Build, verify and render a bare 47.3°N plate (horizon + almucantars).
#
#     julia --project=. examples/first_plate.jl

using Astrolabes

plate = Plate(47.3; almucantar_step = 2)
report = verify(plate)
show(stdout, MIME"text/plain"(), report)

path = render_svg(plate, joinpath(@__DIR__, "plate_47.3N.svg"); diameter_mm = 150)
println("\nwrote ", path)
