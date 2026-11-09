# Horizon ↔ equatorial conversions (wrapping SOFA.hd2ae / SOFA.ae2hd).
# Azimuth is measured from north through east, as in SOFA.

"""
    altaz(H, δ, φ) -> (az, alt)

Azimuth (from north through east) and altitude, in degrees, of a point at hour angle
`H` and declination `δ` seen from latitude `φ` (all degrees).
"""
function altaz(H::Real, δ::Real, φ::Real)
    r = SOFA.hd2ae(deg2rad(Float64(H)), deg2rad(Float64(δ)), deg2rad(Float64(φ)))
    return (az = rad2deg(r.azi), alt = rad2deg(r.alt))
end

"""
    hadec(az, alt, φ) -> (H, dec)

Hour angle (in (−180°, 180°]) and declination, in degrees, of a point at azimuth `az`
(from north through east) and altitude `alt`, seen from latitude `φ`.
"""
function hadec(az::Real, alt::Real, φ::Real)
    ha, dec = SOFA.ae2hd(deg2rad(Float64(az)), deg2rad(Float64(alt)), deg2rad(Float64(φ)))
    H = rad2deg(ha)
    return (H = H > 180 ? H - 360 : H, dec = rad2deg(dec))
end
