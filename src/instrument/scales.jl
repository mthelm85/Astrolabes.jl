# Circular scales: graduations around a centre, read by the angle of a rule or alidade.

"One graduation: the `value` it marks, its `angle` (radians) and radial extent `r1`–`r2`."
struct ScaleTick
    value::Float64
    angle::Float64
    r1::Float64
    r2::Float64
end

"""
    CircularScale(name, center, ticks, labels, rings)

Graduations around `center`. Values increase monotonically along the ticks (sorted by
value); reading a scale interpolates linearly between the two drawn ticks on either
side of the reading angle.
"""
struct CircularScale
    name::Symbol
    center::Pt
    ticks::Vector{ScaleTick}
    labels::Vector{Label}
    rings::Vector{Primitive}
end

tick_segment(sc::CircularScale, t::ScaleTick) =
    Segment(sc.center + polar(t.r1, t.angle), sc.center + polar(t.r2, t.angle))
scale_prims(sc::CircularScale) =
    Primitive[[tick_segment(sc, t) for t in sc.ticks]; sc.rings]

# tick angles unwrapped so consecutive ticks differ by less than π
function unwrapped_angles(sc::CircularScale)
    a = [t.angle for t in sc.ticks]
    for i = 2:length(a)
        a[i] = a[i-1] + (mod(a[i] - a[i-1] + π, 2π) - π)
    end
    return a
end

"""
    read_scale(sc, θ; period = nothing) -> Float64

The value the scale shows at angle `θ` (radians), interpolating between drawn ticks. For a
closed scale give the value `period` (e.g. 24 hours) so the last interval wraps round.
Throws if `θ` is outside an open scale.
"""
function read_scale(sc::CircularScale, θ::Real; period = nothing)
    a = unwrapped_angles(sc)
    v = [t.value for t in sc.ticks]
    if period !== nothing
        # close the loop with a virtual tick one period on
        sgn = sign(a[end] - a[1])
        push!(a, a[1] + sgn * 2π)
        push!(v, v[1] + period)
    end
    for i = 1:(length(a)-1)
        lo, hi = a[i], a[i+1]
        t = mod(θ - lo + π, 2π) - π           # θ relative to lo, in (−π, π]
        span = hi - lo
        f = t / span
        if -1e-12 <= f <= 1 + 1e-12 && abs(span) < π
            val = v[i] + f * (v[i+1] - v[i])
            return period === nothing ? val : mod(val, period)
        end
    end
    throw(ArgumentError("angle $θ is outside scale $(sc.name)"))
end

"""
    scale_angle(sc, value; period = nothing) -> Float64

Angle (radians) at which the scale shows `value`, interpolating between drawn ticks.
"""
function scale_angle(sc::CircularScale, value::Real; period = nothing)
    a = unwrapped_angles(sc)
    v = [t.value for t in sc.ticks]
    if period !== nothing
        push!(a, a[1] + sign(a[end] - a[1]) * 2π)
        push!(v, v[1] + period)
        value = v[1] + mod(value - v[1], period)
    end
    i = searchsortedlast(v, value)
    i = clamp(i, 1, length(v) - 1)
    (v[1] - 1e-9 <= value <= v[end] + 1e-9) ||
        throw(ArgumentError("value $value is outside scale $(sc.name)"))
    f = (value - v[i]) / (v[i+1] - v[i])
    return a[i] + f * (a[i+1] - a[i])
end

"""
    radial_scale(name, center, values, angle_of_value, r_in, r_out; tick_len, labels, ...)

Build a circular scale whose tick for `v` lies at `angle_of_value(v)` and runs inward
from `r_out`; `tick_len(v)` gives each tick's length. `label_values` are labelled at
radius `label_r` with height `label_h` by `label_text(v)`.
"""
function radial_scale(
    name,
    center,
    values,
    angle_of_value,
    r_in,
    r_out;
    tick_len,
    label_values = (),
    label_r = r_in,
    label_h = 0.0,
    label_text = v -> string(round(Int, v)),
    rings = true,
    outward = false,
)
    ticks = ScaleTick[]
    for v in values
        θ = angle_of_value(v)
        L = tick_len(v)
        push!(
            ticks,
            outward ? ScaleTick(v, θ, r_in, r_in + L) : ScaleTick(v, θ, r_out - L, r_out),
        )
    end
    labels = Label[]
    for v in label_values
        θ = angle_of_value(v)
        push!(
            labels,
            Label(
                label_text(v),
                center + polar(label_r, θ),
                label_h;
                angle = upright(θ - π / 2),
            ),
        )
    end
    rs = rings ? Primitive[Circle(center, r_in), Circle(center, r_out)] : Primitive[]
    return CircularScale(name, center, ticks, labels, rs)
end
