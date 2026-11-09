# Sexagesimal input (via AstroAngles.jl).

"""
    parse_latitude(s) -> Float64

Parse a latitude such as `"47°18′N"`, `"33d52m S"`, `"-33:52"` or `"51.75"` into signed
degrees (south negative).
"""
function parse_latitude(s::AbstractString)
    t = strip(s)
    sgn = 1.0
    if !isempty(t) && uppercase(last(t)) in ('N', 'S')
        sgn = uppercase(last(t)) == 'S' ? -1.0 : 1.0
        t = strip(chop(t))
    end
    φ = sgn * AstroAngles.dms2deg(t)
    abs(φ) <= 90 || throw(ArgumentError("latitude out of range: $s"))
    return φ
end

Plate(latitude::AbstractString; kw...) = Plate(parse_latitude(latitude); kw...)
