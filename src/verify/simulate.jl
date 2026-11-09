# Using the instrument in simulation, working only on the drawn geometry:
# set the alidade on a calendar tick to read the Sun's longitude on the zodiac ring,
# find that longitude on the rete's graduated ecliptic, turn the rete until a body meets
# a plate line, and lay the rule across the Sun to read the hour on the limb.

"""
    Simulator

Operates an [`Astrolabe`](@ref) on its drawn primitives. Optional perturbations model
fabrication error: `rete_offset` (plate units, rete frame) displaces the rete on its pin,
`rete_scale` scales it relative to the plate, and `reading_offset` (radians) is added to
every reading of the rule.
"""
struct Simulator
    a::Astrolabe
    plate::Plate
    rete_offset::Pt
    rete_scale::Float64
    reading_offset::Float64
end

"""
    simulate(a::Astrolabe; plate = 1, rete_offset = Pt(0, 0), rete_scale = 1.0,
             reading_offset = 0.0) -> Simulator
"""
simulate(
    a::Astrolabe;
    plate::Integer = 1,
    rete_offset::Pt = Pt(0, 0),
    rete_scale::Real = 1.0,
    reading_offset::Real = 0.0,
) = Simulator(a, a.plates[plate], rete_offset, Float64(rete_scale), Float64(reading_offset))

"A calendar date on the instrument's calendar ring: `(month, day)`."
const DateMD = Tuple{Int,Int}

function calendar_day(sim::Simulator, date::DateMD)
    i = findfirst(d -> d.month == date[1] && d.day == date[2], sim.a.back.calendar)
    i === nothing && throw(ArgumentError("no calendar tick for $(date)"))
    return sim.a.back.calendar[i]
end

"""
    calendar_longitude(sim, (month, day)) -> λ

The Sun's ecliptic longitude read on the back: the alidade is laid on the day's tick
and the longitude read where it crosses the zodiac ring.
"""
function calendar_longitude(sim::Simulator, date::DateMD)
    d = calendar_day(sim, date)
    θ = angle_of(d.outer) + sim.reading_offset
    return read_scale(sim.a.back.zodiac, θ; period = 360.0)
end

"""
    eot_reading(sim, (month, day)) -> minutes

The equation of time read on the back where the alidade, laid on the day's tick, crosses
the drawn curve.
"""
function eot_reading(sim::Simulator, date::DateMD)
    b = sim.a.back
    θ = angle_of(calendar_day(sim, date).outer)
    ray = Segment(Pt(0, 0), polar(2 * b.eot_zero, θ))
    pts = b.eot_curve.pts
    hits = Pt[]
    for i = 1:length(pts)
        seg = Segment(pts[i], pts[mod1(i + 1, length(pts))])
        append!(hits, intersect_prims(ray, seg; tol = 1e-10))
    end
    isempty(hits) && error("the alidade misses the equation-of-time curve")
    r = norm2(first(hits))
    return (r - b.eot_zero) / b.eot_scale
end

"""
    ecliptic_position(sim, λ) -> Pt

Rete-frame point of longitude `λ` on the drawn ecliptic, interpolated between its
graduations (six-point Lagrange interpolation of the angle about the ecliptic centre).
"""
function ecliptic_position(sim::Simulator, λ::Real)
    r = sim.a.rete
    E = r.ecliptic
    ticks = r.ticks
    n = length(ticks)
    step = ticks[2].λ - ticks[1].λ
    λ = mod(λ, 360)
    i0 = floor(Int, λ / step)               # tick at or below λ (index from 0)
    idx = [mod(i0 + j, n) + 1 for j = -2:3]
    xs = [ticks[1].λ + step * (i0 + j) for j = -2:3]
    ψ = [angle_of(ticks[i].outer - E.c) for i in idx]
    for j = 2:6
        ψ[j] = ψ[j-1] + (mod(ψ[j] - ψ[j-1] + π, 2π) - π)
    end
    val = 0.0
    for j = 1:6
        Lj = 1.0
        for m = 1:6
            m == j || (Lj *= (λ - xs[m]) / (xs[j] - xs[m]))
        end
        val += Lj * ψ[j]
    end
    return E.c + polar(E.r, val)
end

"Rete-frame point of a body: `:Sun` (with a date) or a star name."
function body_point(sim::Simulator, body, date::DateMD)
    if body === :Sun
        return ecliptic_position(sim, calendar_longitude(sim, date))
    end
    name = string(body)
    i = findfirst(p -> lowercase(p.star.name) == lowercase(name), sim.a.rete.pointers)
    i === nothing && throw(ArgumentError("$name is not on the rete"))
    return sim.a.rete.pointers[i].tip
end

placed(sim::Simulator, b::Pt) = sim.rete_scale * b + sim.rete_offset

# east side of the plate (where bodies rise)
is_east(sim::Simulator, p::Pt) =
    sim.plate.projection.hemisphere === :north ? p.x < 0 : p.x > 0

"""
    turn_to(sim, b, prims, side) -> θ

Rotation (radians) that brings rete point `b` onto the drawn `prims` on the given
`side` (`:east`, `:west` or `:upper`, the zenith side of the meridian).
"""
function turn_to(sim::Simulator, b::Pt, prims, side::Symbol)
    bp = placed(sim, b)
    C = Circle(Pt(0, 0), norm2(bp))
    cands = Pt[]
    for q in prims
        append!(cands, intersect_prims(C, q; tol = 1e-9))
    end
    cands = if side === :upper
        filter(p -> p.y > 0, cands)
    elseif side === :east
        filter(p -> is_east(sim, p), cands)
    else
        filter(p -> !is_east(sim, p), cands)
    end
    isempty(cands) && return nothing
    q = first(cands)
    return mod(angle_of(q) - angle_of(bp) + π, 2π) - π
end

"Clock reading (hours) of the rule laid across rete point `b` turned by `θ`."
function rule_reading(sim::Simulator, b::Pt, θ::Real)
    p = rotate(placed(sim, b), θ)
    return read_scale(sim.a.mater.hours, angle_of(p) + sim.reading_offset; period = 24.0)
end

function plate_prims(sim::Simulator, kind::Symbol, value = nothing)
    els = [
        e for e in sim.plate.elements if
        e.kind === kind && (value === nothing || isapprox(e.value, value; atol = 1e-9))
    ]
    return reduce(vcat, [e.prims for e in els]; init = Primitive[])
end

"""
    event(sim, body, (month, day), kind; altitude = 0) -> NamedTuple or nothing

`kind` is `:rise`, `:set`, `:transit` or `:altitude_east` / `:altitude_west`. Returns
the `apparent` solar time and the `clock` reading (hours), and the clock time corrected
by the equation of time read on the back (`mean`). `nothing` if the event does not occur.
"""
function event(sim::Simulator, body, date::DateMD, kind::Symbol; altitude::Real = 0.0)
    b = body_point(sim, body, date)
    sun = body_point(sim, :Sun, date)
    prims, side = if kind === :transit
        (plate_prims(sim, :meridian), :upper)
    else
        k = altitude == 0 ? :horizon : altitude < 0 ? :twilight : :almucantar
        pr = k === :horizon ? plate_prims(sim, :horizon) : plate_prims(sim, k, altitude)
        isempty(pr) && throw(ArgumentError("no plate line at altitude $altitude"))
        (pr, kind in (:rise, :altitude_east) ? :east : :west)
    end
    θ = turn_to(sim, b, prims, side)
    θ === nothing && return nothing
    clock = rule_reading(sim, sun, θ)
    apparent = mod(clock - sim.a.mater.clock_offset, 24)
    mean = mod(clock - eot_reading(sim, date) / 60, 24)
    return (apparent = apparent, clock = clock, mean = mean)
end

"Sunrise on `(month, day)`; see [`event`](@ref)."
sunrise(sim::Simulator, date::DateMD) = event(sim, :Sun, date, :rise)
"Sunset on `(month, day)`."
sunset(sim::Simulator, date::DateMD) = event(sim, :Sun, date, :set)
"Rising of a rete star on `(month, day)`."
star_rise(sim::Simulator, name, date::DateMD) = event(sim, name, date, :rise)
"Setting of a rete star."
star_set(sim::Simulator, name, date::DateMD) = event(sim, name, date, :set)
"Upper transit of a rete star."
star_transit(sim::Simulator, name, date::DateMD) = event(sim, name, date, :transit)

"""
    time_from_altitude(sim, body, altitude, (month, day); side = :east)

Time at which `body` stands at `altitude` (which must be a drawn almucantar, the
horizon, or a twilight line).
"""
time_from_altitude(
    sim::Simulator,
    body,
    altitude::Real,
    date::DateMD;
    side::Symbol = :east,
) = event(sim, body, date, side === :east ? :altitude_east : :altitude_west; altitude)

"""
    sunrise_azimuth(sim, (month, day)) -> degrees

Azimuth of sunrise, interpolated along the horizon between the drawn azimuth lines.
"""
function sunrise_azimuth(sim::Simulator, date::DateMD)
    hor = plate_prims(sim, :horizon)
    sun = body_point(sim, :Sun, date)
    θ = turn_to(sim, sun, hor, :east)
    θ === nothing && return nothing
    S = rotate(placed(sim, sun), θ)
    # known points on the horizon: azimuth lines and the meridian
    marks = Tuple{Float64,Pt}[]
    for el in sim.plate.elements
        if el.kind in (:azimuth, :meridian)
            for q in el.prims, h in hor, p in intersect_prims(q, h; tol = 1e-9)
                az =
                    el.kind === :meridian ?
                    (p.y > 0 ? 180.0 : 0.0) * (sim.plate.latitude >= 0 ? 1 : -1) :
                    (is_east(sim, p) ? el.value : el.value + 180)
                push!(marks, (mod(az, 360), p))
            end
        end
    end
    hc = only(hor)
    ctr = hc isa Arc ? hc.c : Pt(0, 0)
    ang(p) = hc isa Segment ? dot2(p - hc.a, unit(hc.b - hc.a)) : angle_of(p - ctr)
    t = ang(S)
    east = [m for m in marks if is_east(sim, m[2])]
    sort!(east; by = m -> ang(m[2]))
    for i = 1:(length(east)-1)
        t1, t2 = ang(east[i][2]), ang(east[i+1][2])
        if min(t1, t2) <= t <= max(t1, t2)
            f = (t - t1) / (t2 - t1)
            return east[i][1] + f * (east[i+1][1] - east[i][1])
        end
    end
    return nothing
end
