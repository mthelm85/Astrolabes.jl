# Low-precision solar coordinates, Meeus, *Astronomical Algorithms* (2nd ed.), ch. 25
# (about 0.01°), and the equation of time, ch. 28. Unlike SOFA's epv00 this has no
# 1900–2100 limit, so it serves historical instruments.

"""
    sun_position(jd) -> NamedTuple

Apparent geocentric position of the Sun at Julian Ephemeris Day `jd` (TT). Returns
degrees: `longitude` (apparent λ), `ra`, `dec`, `obliquity` (true ε), plus the
`mean_longitude` L₀, `mean_anomaly` M and `distance` (AU). Also accepts an `Epoch`.
"""
function sun_position(jd::Real)
    T = julian_centuries(jd)
    L0 = 280.46646 + T * (36000.76983 + 0.0003032T)
    M = 357.52911 + T * (35999.05029 - 0.0001537T)
    e = 0.016708634 - T * (0.000042037 + 0.0000001267T)
    Mr = deg2rad(M)
    C =
        (1.914602 - T * (0.004817 + 0.000014T)) * sin(Mr) +
        (0.019993 - 0.000101T) * sin(2Mr) +
        0.000289 * sin(3Mr)
    true_long = L0 + C
    ν = deg2rad(M + C)
    R = 1.000001018 * (1 - e^2) / (1 + e * cos(ν))
    Ω = deg2rad(125.04 - 1934.136T)
    λ = true_long - 0.00569 - 0.00478 * sin(Ω)
    ε0 = mean_obliquity_meeus(T)
    ε = ε0 + 0.00256 * cos(Ω)
    λr, εr = deg2rad(λ), deg2rad(ε)
    α = atan(cos(εr) * sin(λr), cos(λr))
    δ = asin(sin(εr) * sin(λr))
    return (
        longitude = mod(λ, 360.0),
        ra = mod(rad2deg(α), 360.0),
        dec = rad2deg(δ),
        obliquity = ε,
        mean_longitude = mod(L0, 360.0),
        mean_anomaly = mod(M, 360.0),
        distance = R,
    )
end

sun_position(e::Epoch) = sun_position(julian_day(e))

# Meeus eq. 22.2 (IAU 1980), degrees.
mean_obliquity_meeus(T) =
    23.0 + 26 / 60 + (21.448 - T * (46.8150 + T * (0.00059 - 0.001813T))) / 3600

"""
    equation_of_time(jd) -> Float64

Equation of time (apparent − mean solar time) in **minutes** at Julian Ephemeris Day
`jd`, Meeus eq. 28.1 with the low-precision solar position. Also accepts an `Epoch`.
"""
function equation_of_time(jd::Real)
    T = julian_centuries(jd)
    s = sun_position(jd)
    Ω = deg2rad(125.04452 - 1934.136261T)
    L = deg2rad(280.4665 + 36000.7698T)
    L′ = deg2rad(218.3165 + 481267.8813T)
    Δψ = (-17.20 * sin(Ω) - 1.32 * sin(2L) - 0.23 * sin(2L′) + 0.21 * sin(2Ω)) / 3600
    E = s.mean_longitude - 0.0057183 - s.ra + Δψ * cosd(s.obliquity)
    E = mod(E + 180.0, 360.0) - 180.0
    return 4E
end

equation_of_time(e::Epoch) = equation_of_time(julian_day(e))
