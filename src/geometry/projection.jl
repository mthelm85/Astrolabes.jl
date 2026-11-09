# Stereographic projection of the celestial sphere onto the equatorial plane.
#
# Sky frame: z toward the north celestial pole, y toward the upper meridian on the
# equator (hour angle H = 0), x toward the west (H = +90°). A point at (H, δ) has
# v = (cosδ sinH, cosδ cosH, sinδ).
#
# :north — project from the south celestial pole: p = R (vx, vy) / (1 + vz).
#          Radius r = R tan((90° − δ)/2); the meridian runs along +y toward the zenith,
#          east is on the left and the rete turns clockwise.
# :south — project from the north celestial pole and mirror x: p = R (−vx, vy) / (1 − vz).
#          The plate for latitude −φ is then the mirror image of the plate for +φ, with
#          east on the right (the observer faces north) and the rete turning anticlockwise.

"""
    Stereographic(hemisphere = :north; R = 1.0)

Polar stereographic projection used by a planispheric astrolabe. `:north` projects from
the south celestial pole; `:south` projects from the north celestial pole and mirrors the
result left–right. `R` is the radius of the projected celestial equator.
"""
struct Stereographic
    hemisphere::Symbol
    R::Float64
    function Stereographic(hemisphere::Symbol, R::Real)
        hemisphere in (:north, :south) ||
            throw(ArgumentError("hemisphere must be :north or :south, got :$hemisphere"))
        R > 0 || throw(ArgumentError("R must be positive"))
        return new(hemisphere, Float64(R))
    end
end
Stereographic(hemisphere::Symbol = :north; R::Real = 1.0) = Stereographic(hemisphere, R)

"""
    project(P::Stereographic, H, δ) -> Pt

Plate position of the point at hour angle `H` and declination `δ` (degrees).
"""
function project(P::Stereographic, H::Real, δ::Real)
    sH, cH = sincosd(H)
    sδ, cδ = sincosd(δ)
    if P.hemisphere === :north
        return Pt(P.R * cδ * sH / (1 + sδ), P.R * cδ * cH / (1 + sδ))
    else
        return Pt(-P.R * cδ * sH / (1 - sδ), P.R * cδ * cH / (1 - sδ))
    end
end

"""
    radius_of_dec(P::Stereographic, δ) -> Float64

Plate radius of the declination circle `δ` (degrees).
"""
radius_of_dec(P::Stereographic, δ::Real) =
    P.hemisphere === :north ? P.R * tand((90 - δ) / 2) : P.R * tand((90 + δ) / 2)

"""
    unproject(P::Stereographic, p::Pt) -> (H, dec)

Inverse projection: hour angle (in (−180°, 180°]) and declination, degrees.
"""
function unproject(P::Stereographic, p::Pt)
    ρ = norm2(p) / P.R
    if P.hemisphere === :north
        return (H = atand(p.x, p.y), dec = 90 - 2 * atand(ρ))
    else
        return (H = atand(-p.x, p.y), dec = 2 * atand(ρ) - 90)
    end
end

"""
    project_altaz(P::Stereographic, az, alt, φ) -> Pt

Plate position of the horizon point (`az` from north through east, `alt`) for an
observer at latitude `φ` (degrees).
"""
function project_altaz(P::Stereographic, az::Real, alt::Real, φ::Real)
    h = hadec(az, alt, φ)
    return project(P, h.H, h.dec)
end
