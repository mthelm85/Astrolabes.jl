# Latitude-specific plates (climates).
#
# Plate formulas are written for the northern projection with |φ|. By construction
# (see projection.jl) the southern plate for −φ is the left–right mirror of the
# northern plate for +φ, and every plate line set is symmetric about the meridian, so
# the same primitives serve both. The verification harness always uses the true
# projection for the plate's hemisphere, so this shortcut is itself checked.

"""
    PlateElement(kind, value, prims, layer)

One family of plate lines: `kind` (`:equator`, `:tropic`, `:limb`, `:horizon`,
`:almucantar`), its defining `value` in degrees (a declination for circles of
declination, an altitude for almucantars), the clipped primitives (plate units, R = 1)
and the fabrication `layer` (`:cut`, `:score`, `:engrave`, `:guide`).
"""
struct PlateElement
    kind::Symbol
    value::Float64
    prims::Vector{Primitive}
    layer::Symbol
end

"""
    Plate(latitude; epoch = Epoch(2026.0), almucantar_step = 2, hemisphere = auto)

A plate for `latitude` (degrees, south negative). The hemisphere defaults to the sign of
the latitude (`:north` for φ = 0). Latitudes beyond ±89.5° are clamped with a warning.
Currently draws the equator, tropics, limb, horizon and almucantars.
"""
struct Plate
    latitude::Float64
    projection::Stereographic
    epoch::Epoch
    obliquity::Float64
    almucantar_step::Float64
    elements::Vector{PlateElement}
end

const MAX_LATITUDE = 89.5

function Plate(
    latitude::Real;
    epoch::Epoch = Epoch(2026.0),
    almucantar_step::Real = 2,
    hemisphere::Symbol = latitude >= 0 ? :north : :south,
)
    φ = Float64(latitude)
    abs(φ) < 90 || throw(ArgumentError("latitude must be in (−90°, 90°), got $φ"))
    if abs(φ) > MAX_LATITUDE
        @warn "Latitude $(φ)° clamped to ±$(MAX_LATITUDE)°: the plate degenerates near the pole."
        φ = copysign(MAX_LATITUDE, φ)
    end
    0 < almucantar_step < 90 || throw(ArgumentError("almucantar_step must be in (0, 90)"))
    P = Stereographic(hemisphere)
    ε = obliquity(epoch)
    elements = plate_elements(P, φ, ε, Float64(almucantar_step))
    return Plate(φ, P, epoch, ε, Float64(almucantar_step), elements)
end

"""
    limb_radius(P::Stereographic, ε) -> Float64

Radius of the limb: the outer tropic (Capricorn for a northern instrument, Cancer for a
southern one).
"""
limb_radius(P::Stereographic, ε::Real) = radius_of_dec(P, outer_tropic(P, ε))
limb_radius(p::Plate) = limb_radius(p.projection, p.obliquity)

outer_tropic(P::Stereographic, ε) = P.hemisphere === :north ? -ε : ε
inner_tropic(P::Stereographic, ε) = -outer_tropic(P, ε)

"""
    almucantar_primitive(φ, a; R = 1) -> Circle or Line

Unclipped projection of the almucantar of altitude `a` at latitude `φ` (degrees),
northern convention. It cuts the meridian at `y₁ = −R tan((φ − a)/2)` (north side) and
`y₂ = R cot((φ + a)/2)` (south side); when `φ + a = 0` the circle passes through the
projection pole and becomes the line `y = y₁`.
"""
function almucantar_primitive(φ::Real, a::Real; R::Real = 1.0)
    y1 = -R * tand((φ - a) / 2)
    s = sind((φ + a) / 2)
    abs(s) < 1e-12 && return Line(Pt(0.0, y1), Pt(1.0, 0.0))
    y2 = R * cosd((φ + a) / 2) / s
    return Circle(Pt(0.0, (y1 + y2) / 2), abs(y2 - y1) / 2)
end

function plate_elements(P::Stereographic, φ::Float64, ε::Float64, step::Float64)
    φn = abs(φ)                     # see the note at the top of this file
    rl = limb_radius(P, ε)
    D = Circle(Pt(0, 0), rl)
    els = PlateElement[]
    dec_circle(δ) = Circle(Pt(0, 0), radius_of_dec(P, δ))
    push!(
        els,
        PlateElement(:limb, outer_tropic(P, ε), [dec_circle(outer_tropic(P, ε))], :cut),
    )
    push!(els, PlateElement(:equator, 0.0, [dec_circle(0.0)], :engrave))
    push!(
        els,
        PlateElement(
            :tropic,
            inner_tropic(P, ε),
            [dec_circle(inner_tropic(P, ε))],
            :engrave,
        ),
    )
    push!(
        els,
        PlateElement(
            :horizon,
            0.0,
            clip_to_disk(almucantar_primitive(φn, 0.0; R = P.R), D),
            :engrave,
        ),
    )
    a = step
    while a < 90 - 1e-9
        prims = clip_to_disk(almucantar_primitive(φn, a; R = P.R), D)
        isempty(prims) || push!(els, PlateElement(:almucantar, a, prims, :engrave))
        a += step
    end
    return els
end

function Base.show(io::IO, p::Plate)
    print(
        io,
        "Plate(",
        p.latitude,
        "°, :",
        p.projection.hemisphere,
        ", ",
        length(p.elements),
        " elements, ε = ",
        round(p.obliquity; digits = 4),
        "°)",
    )
end
