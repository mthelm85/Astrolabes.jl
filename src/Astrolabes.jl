"""
    Astrolabes

Geometrically exact, fabrication-ready astrolabes for any latitude and epoch, with
built-in verification of every drawn line against spherical astronomy.

Conventions: angles are in **degrees** at the public API and radians internally.
Plate geometry is computed with the equator radius `R = 1` and scaled to millimetres
only when rendering.
"""
module Astrolabes

using LinearAlgebra: dot, norm
using Printf: @sprintf
using SOFA: SOFA
using AstroAngles: AstroAngles
using Clipper: Clipper

# astronomy layer (thin wrapper over SOFA.jl + our own solar model)
include("astro/epoch.jl")
include("astro/precession.jl")
include("astro/sun.jl")
include("astro/sphere.jl")

# geometry
include("geometry/primitives.jl")
include("geometry/regions.jl")
include("geometry/solids.jl")
include("geometry/projection.jl")
include("geometry/sampling.jl")

# instrument
include("render/font.jl")
include("render/profiles.jl")
include("instrument/plate.jl")
include("astro/angles.jl")
include("instrument/scales.jl")
include("instrument/parts.jl")
include("instrument/catalog.jl")
include("instrument/rete.jl")
include("instrument/mater.jl")
include("instrument/rule.jl")
include("instrument/back.jl")
include("instrument/astrolabe.jl")

# verification + rendering
include("verify/report.jl")
include("verify/geometric.jl")
include("verify/simulate.jl")
include("verify/instrument.jl")
include("render/svg.jl")
include("render/fabricate.jl")

export Epoch, julian_day, calendar_to_jd
export Star, precess_to, obliquity
export sun_position, equation_of_time
export altaz, hadec, parse_latitude
export Pt, Circle, Line, Segment, Arc, Polyline, Primitive
export intersect_prims, clip, clip_to_disk, distance_to, sample_points
export Disk, OutsideDisk, HalfPlane, rotate, translate, scale, mirror_x
export Shape, Label
export Stereographic, project, unproject
export CurveCheck, check_curve, check_point
export Plate, PlateElement, limb_radius
export VerificationReport, verify
export render_svg, render, render_preview
export Profile, LaserCut, Metal, PCB, Paper
export Astrolabe, astrolabe, Location, parts, Part
export Rete, ReteStyle, Mater, Back, Rule, Alidade
export catalog_stars, find_star, traditional_name
export Simulator, simulate, sunrise, sunset, star_rise, star_set, star_transit
export time_from_altitude, sunrise_azimuth, calendar_longitude, eot_reading, error_budget

end
