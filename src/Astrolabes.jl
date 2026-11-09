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

# astronomy layer (thin wrapper over SOFA.jl + our own solar model)
include("astro/epoch.jl")
include("astro/precession.jl")
include("astro/sun.jl")
include("astro/sphere.jl")

# geometry
include("geometry/primitives.jl")
include("geometry/projection.jl")
include("geometry/sampling.jl")

# instrument
include("instrument/plate.jl")
include("astro/angles.jl")

# verification + rendering
include("verify/report.jl")
include("verify/geometric.jl")
include("render/svg.jl")

export Epoch, julian_day, calendar_to_jd
export Star, precess_to, obliquity
export sun_position, equation_of_time
export altaz, hadec, parse_latitude
export Pt, Circle, Line, Segment, Arc, Polyline, Primitive
export intersect_prims, clip_to_disk, distance_to, sample_points
export Stereographic, project, unproject
export CurveCheck, check_curve, check_point
export Plate, PlateElement, limb_radius
export VerificationReport, verify
export render_svg

end
