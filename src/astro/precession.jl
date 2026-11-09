# Star positions at arbitrary epochs: proper motion (SOFA.pmsafe) followed by
# Vondrák et al. (2011) long-term precession (SOFA.ltp), valid for ±200 000 years.

const MAS2RAD = deg2rad(1 / 3_600_000)

"""
    Star(name, ra, dec; pmra = 0, pmdec = 0, parallax = 0, rv = 0, vmag = NaN)

A catalogue star at epoch and equinox J2000 (ICRS). `ra` and `dec` are in degrees.
`pmra` is μα* = μα·cos δ and `pmdec` is μδ, both in mas/yr; `parallax` is in mas and
`rv` in km/s.
"""
struct Star
    name::String
    ra::Float64
    dec::Float64
    pmra::Float64
    pmdec::Float64
    parallax::Float64
    rv::Float64
    vmag::Float64
end

function Star(
    name::AbstractString,
    ra::Real,
    dec::Real;
    pmra::Real = 0,
    pmdec::Real = 0,
    parallax::Real = 0,
    rv::Real = 0,
    vmag::Real = NaN,
)
    return Star(String(name), ra, dec, pmra, pmdec, parallax, rv, vmag)
end

radec_to_vec(α, δ) = [cos(δ) * cos(α), cos(δ) * sin(α), sin(δ)]
vec_to_radec(v) = (mod2pi(atan(v[2], v[1])), atan(v[3], hypot(v[1], v[2])))

"""
    precession_matrix(e::Epoch) -> Matrix{Float64}

Rotation from the J2000 mean frame (GCRS) to the mean equator and equinox of `e`,
from SOFA's long-term model (`SOFA.ltp`).
"""
precession_matrix(e::Epoch) = SOFA.ltp(e.year)

"""
    precess_to(star::Star, e::Epoch; proper_motion = true) -> (ra, dec)

Mean right ascension and declination (degrees) of `star` referred to the mean equator
and equinox of `e`. Space motion is applied with `SOFA.pmsafe` and precession with the
long-term model `SOFA.ltp`. Nutation and aberration are ignored, which is appropriate
for an instrument scale.
"""
function precess_to(s::Star, e::Epoch; proper_motion::Bool = true)
    α, δ = deg2rad(s.ra), deg2rad(s.dec)
    if proper_motion && (s.pmra != 0 || s.pmdec != 0)
        pmr = s.pmra * MAS2RAD / cos(δ)       # SOFA wants dα/dt, not μα*
        pmd = s.pmdec * MAS2RAD
        r = SOFA.pmsafe(
            α,
            δ,
            pmr,
            pmd,
            s.parallax / 1000,
            s.rv,
            J2000_JD,
            0.0,
            J2000_JD,
            julian_day(e) - J2000_JD,
        )
        α, δ = r.ra, r.dec
    end
    v = precession_matrix(e) * radec_to_vec(α, δ)
    α2, δ2 = vec_to_radec(v)
    return (ra = rad2deg(α2), dec = rad2deg(δ2))
end

"""
    obliquity(e::Epoch) -> Float64

Mean obliquity of the ecliptic in degrees: the angle between the mean equator pole and
the ecliptic pole of the long-term precession model (`SOFA.ltpequ`, `SOFA.ltpecl`). It
agrees with IAU 2006 (`SOFA.obl06`) near the present and stays valid over millennia.
"""
function obliquity(e::Epoch)
    p = SOFA.ltpequ(e.year)
    z = SOFA.ltpecl(e.year)
    return rad2deg(atan(norm(cross3(p, z)), dot(p, z)))
end

obliquity(year::Real) = obliquity(Epoch(year))

cross3(a, b) =
    [a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1]]
