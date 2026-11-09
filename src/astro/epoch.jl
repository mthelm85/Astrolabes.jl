# Epochs and calendars.

const J2000_JD = 2451545.0
const DAYS_PER_JULIAN_YEAR = 365.25

"""
    calendar_to_jd(year, month, day; calendar = :gregorian) -> Float64

Julian Day (at the given fractional `day`) of a calendar date, using the algorithm of
Meeus, *Astronomical Algorithms*, ch. 7. `calendar` is `:gregorian` (proleptic for dates
before 1582) or `:julian`. Astronomical year numbering is used (1 BC = year 0).
"""
function calendar_to_jd(
    year::Integer,
    month::Integer,
    day::Real;
    calendar::Symbol = :gregorian,
)
    calendar in (:gregorian, :julian) ||
        throw(ArgumentError("calendar must be :gregorian or :julian, got :$calendar"))
    1 <= month <= 12 || throw(ArgumentError("month must be in 1:12, got $month"))
    y, m = month <= 2 ? (year - 1, month + 12) : (year, month)
    b = if calendar === :gregorian
        a = fld(y, 100)
        2 - a + fld(a, 4)
    else
        0
    end
    return floor(365.25 * (y + 4716)) + floor(30.6001 * (m + 1)) + day + b - 1524.5
end

"""
    Epoch(year; calendar = :gregorian)
    Epoch(year, month, day; calendar = :gregorian)

An instant expressed as a **Julian epoch** (TT), e.g. `Epoch(2026.0)` or `Epoch(1391.0)`.
`calendar` records which civil calendar the instrument's calendar scales use; it does not
change the instant for the one-argument form. The three-argument form interprets the
date in that calendar.
"""
struct Epoch
    year::Float64
    calendar::Symbol
    function Epoch(year::Real, calendar::Symbol)
        calendar in (:gregorian, :julian) ||
            throw(ArgumentError("calendar must be :gregorian or :julian, got :$calendar"))
        return new(Float64(year), calendar)
    end
end

Epoch(year::Real; calendar::Symbol = :gregorian) = Epoch(year, calendar)

function Epoch(year::Integer, month::Integer, day::Real; calendar::Symbol = :gregorian)
    jd = calendar_to_jd(year, month, day; calendar)
    return Epoch(2000.0 + (jd - J2000_JD) / DAYS_PER_JULIAN_YEAR, calendar)
end

"""
    julian_day(e::Epoch) -> Float64

Julian Date (TT) of the epoch.
"""
julian_day(e::Epoch) = J2000_JD + (e.year - 2000.0) * DAYS_PER_JULIAN_YEAR

"Julian centuries of TT since J2000.0."
julian_centuries(jd::Real) = (jd - J2000_JD) / 36525.0

Base.show(io::IO, e::Epoch) = print(io, "Epoch(", e.year, ", :", e.calendar, ")")
