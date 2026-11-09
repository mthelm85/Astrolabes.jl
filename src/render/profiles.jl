# Fabrication profiles. All dimensions are millimetres.

"Supertype of fabrication profiles."
abstract type Profile end

"""
    LaserCut(; kerf = 0.15, thickness = 3.0, ...)

Laser cutting and vector engraving of sheet material (acrylic, wood). Cut paths are
red hairlines, engraving black and score lines blue by default; most online services
compensate kerf themselves, so `compensate_kerf` is off by default.
"""
Base.@kwdef struct LaserCut <: Profile
    kerf::Float64 = 0.15
    thickness::Float64 = 3.0
    min_feature::Float64 = 0.6
    min_space::Float64 = 0.25
    min_text::Float64 = 1.5
    stroke::Float64 = 0.1
    pin_diameter::Float64 = 3.0
    hole_clearance::Float64 = 0.15
    fit_clearance::Float64 = 0.3
    engrave_margin::Float64 = 0.4
    scale_tolerance::Float64 = 0.001
    compensate_kerf::Bool = false
    colors::Dict{Symbol,String} = Dict(
        :cut => "#ff0000",
        :score => "#0000ff",
        :engrave => "#000000",
        :guide => "#909090",
    )
end

"""
    Metal(; thickness = 1.0, ...)

Sheet metal (brass, steel, aluminium) cut by fibre laser or waterjet, with engraving
or etching. Metal services set the minimum hole and web to about the sheet thickness;
cut and engrave layers are written as separate files by default.
"""
Base.@kwdef struct Metal <: Profile
    thickness::Float64 = 1.0
    kerf::Float64 = 0.2
    min_feature::Float64 = 1.0
    min_space::Float64 = 0.3
    min_text::Float64 = 2.0
    stroke::Float64 = 0.15
    pin_diameter::Float64 = 3.0
    hole_clearance::Float64 = 0.15
    fit_clearance::Float64 = 0.3
    engrave_margin::Float64 = 0.6
    scale_tolerance::Float64 = 0.0005
    compensate_kerf::Bool = false
    split_layers::Bool = true
    colors::Dict{Symbol,String} = Dict(
        :cut => "#ff0000",
        :score => "#0000ff",
        :engrave => "#000000",
        :guide => "#909090",
    )
end

"""
    PCB(; min_trace = 0.15, min_space = 0.15, ...)

Printed-circuit-board fabrication (e.g. ENIG gold on black solder mask): outlines go to
the Edge.Cuts layer, engraved lines to copper (F.Cu, exposed), labels to silkscreen.
Output is per-layer DXF and SVG for import into KiCad.
"""
Base.@kwdef struct PCB <: Profile
    min_trace::Float64 = 0.15
    min_space::Float64 = 0.15
    min_text::Float64 = 1.0
    silk_width::Float64 = 0.15
    thickness::Float64 = 1.6
    min_feature::Float64 = 0.8
    pin_diameter::Float64 = 3.0
    hole_clearance::Float64 = 0.1
    fit_clearance::Float64 = 0.25
    engrave_margin::Float64 = 0.3
    scale_tolerance::Float64 = 0.0002
    compensate_kerf::Bool = false
    colors::Dict{Symbol,String} = Dict(
        :cut => "#ffff00",
        :score => "#c08000",
        :engrave => "#c08000",
        :guide => "#909090",
    )
end

"""
    Paper(; ...)

A 1:1 print for checking fit and legibility before ordering parts. Each part is one SVG
with a 100 mm calibration bar; print at 100 % and measure the bar.
"""
Base.@kwdef struct Paper <: Profile
    stroke::Float64 = 0.15
    min_text::Float64 = 1.2
    min_feature::Float64 = 1.0
    min_space::Float64 = 0.3
    thickness::Float64 = 0.3
    kerf::Float64 = 0.3
    pin_diameter::Float64 = 2.0
    hole_clearance::Float64 = 0.3
    fit_clearance::Float64 = 0.5
    engrave_margin::Float64 = 0.3
    scale_tolerance::Float64 = 0.005
    compensate_kerf::Bool = false
    colors::Dict{Symbol,String} = Dict(
        :cut => "#ff0000",
        :score => "#0000ff",
        :engrave => "#000000",
        :guide => "#909090",
    )
end

stroke_width(p::Profile) = p.stroke
stroke_width(p::PCB) = p.min_trace
kerf(p::Profile) = p.kerf
kerf(::PCB) = 0.0
min_hole(p::Profile) = 0.0
min_hole(p::Metal) = p.thickness
profile_name(p::Profile) = string(nameof(typeof(p)))
split_layers(p::Profile) = false
split_layers(p::Metal) = p.split_layers
