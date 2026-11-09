# 2-D drawing primitives, intersections and clipping to a disk.
# All angles in this file are radians; arcs run counter-clockwise from θ1 to θ2.

"A point (or vector) in the plate plane."
struct Pt
    x::Float64
    y::Float64
end
Pt(x::Real, y::Real) = Pt(Float64(x), Float64(y))

Base.:+(a::Pt, b::Pt) = Pt(a.x + b.x, a.y + b.y)
Base.:-(a::Pt, b::Pt) = Pt(a.x - b.x, a.y - b.y)
Base.:-(a::Pt) = Pt(-a.x, -a.y)
Base.:*(s::Real, a::Pt) = Pt(s * a.x, s * a.y)
Base.:*(a::Pt, s::Real) = s * a
Base.:/(a::Pt, s::Real) = Pt(a.x / s, a.y / s)
Base.isapprox(a::Pt, b::Pt; kw...) = isapprox(a.x, b.x; kw...) && isapprox(a.y, b.y; kw...)
dot2(a::Pt, b::Pt) = a.x * b.x + a.y * b.y
cross2(a::Pt, b::Pt) = a.x * b.y - a.y * b.x
norm2(a::Pt) = hypot(a.x, a.y)
unit(a::Pt) = a / norm2(a)
polar(r::Real, θ::Real) = Pt(r * cos(θ), r * sin(θ))
angle_of(a::Pt) = atan(a.y, a.x)

"Supertype of all drawable geometry."
abstract type Primitive end

"Full circle with centre `c` and radius `r`."
struct Circle <: Primitive
    c::Pt
    r::Float64
end

"Infinite line through `p` with unit direction `d`."
struct Line <: Primitive
    p::Pt
    d::Pt
    Line(p::Pt, d::Pt) = new(p, unit(d))
end

"Straight segment from `a` to `b`."
struct Segment <: Primitive
    a::Pt
    b::Pt
end

"""
    Arc(c, r, θ1, θ2)

Circular arc, centre `c`, radius `r`, running counter-clockwise from angle `θ1` to `θ2`
(radians, `θ1 < θ2 ≤ θ1 + 2π`).
"""
struct Arc <: Primitive
    c::Pt
    r::Float64
    θ1::Float64
    θ2::Float64
    function Arc(c::Pt, r::Real, θ1::Real, θ2::Real)
        θ2 > θ1 || throw(ArgumentError("Arc needs θ2 > θ1"))
        θ2 - θ1 <= 2π + 1e-12 || throw(ArgumentError("Arc spans more than a full turn"))
        return new(c, r, θ1, θ2)
    end
end

"Open or closed polyline through `pts`."
struct Polyline <: Primitive
    pts::Vector{Pt}
    closed::Bool
end
Polyline(pts::Vector{Pt}) = Polyline(pts, false)

# ---------------------------------------------------------------- distance

"""
    distance_to(prim, p::Pt) -> Float64

Euclidean distance from `p` to the drawn set of `prim`.
"""
distance_to(c::Circle, p::Pt) = abs(norm2(p - c.c) - c.r)
distance_to(l::Line, p::Pt) = abs(cross2(l.d, p - l.p))

function distance_to(s::Segment, p::Pt)
    v = s.b - s.a
    L2 = dot2(v, v)
    t = L2 == 0 ? 0.0 : clamp(dot2(p - s.a, v) / L2, 0.0, 1.0)
    return norm2(p - (s.a + t * v))
end

# angle t mapped into [θ1, θ1 + 2π)
wrap_from(t, θ1) = θ1 + mod(t - θ1, 2π)
in_arc_range(a::Arc, t) = wrap_from(t, a.θ1) <= a.θ2

arc_point(a::Arc, θ) = a.c + polar(a.r, θ)

function distance_to(a::Arc, p::Pt)
    if in_arc_range(a, angle_of(p - a.c))
        return abs(norm2(p - a.c) - a.r)
    end
    return min(norm2(p - arc_point(a, a.θ1)), norm2(p - arc_point(a, a.θ2)))
end

function distance_to(pl::Polyline, p::Pt)
    n = length(pl.pts)
    n == 1 && return norm2(p - pl.pts[1])
    d = Inf
    for i = 1:(n-1)
        d = min(d, distance_to(Segment(pl.pts[i], pl.pts[i+1]), p))
    end
    pl.closed && (d = min(d, distance_to(Segment(pl.pts[end], pl.pts[1]), p)))
    return d
end

distance_to(prims::AbstractVector{<:Primitive}, p::Pt) =
    isempty(prims) ? Inf : minimum(distance_to(q, p) for q in prims)

# ---------------------------------------------------------------- sampling

"""
    sample_points(prim, n) -> Vector{Pt}

`n` points spread along `prim` (endpoints included for open primitives).
"""
sample_points(c::Circle, n::Integer) = [c.c + polar(c.r, 2π * k / n) for k = 0:(n-1)]
sample_points(a::Arc, n::Integer) =
    [arc_point(a, a.θ1 + (a.θ2 - a.θ1) * k / (n - 1)) for k = 0:(n-1)]
sample_points(s::Segment, n::Integer) = [s.a + (k / (n - 1)) * (s.b - s.a) for k = 0:(n-1)]
function sample_points(pl::Polyline, n::Integer)
    pts = Pt[]
    m = length(pl.pts)
    per = max(2, cld(n, max(m - 1, 1)))
    for i = 1:(m-1)
        append!(pts, sample_points(Segment(pl.pts[i], pl.pts[i+1]), per))
    end
    return pts
end
sample_points(::Line, ::Integer) =
    throw(ArgumentError("cannot sample an infinite Line; clip it first"))

# ---------------------------------------------------------------- intersections

function line_line(p1::Pt, d1::Pt, p2::Pt, d2::Pt)
    den = cross2(d1, d2)
    abs(den) < 1e-15 && return Pt[]
    t = cross2(p2 - p1, d2) / den
    return [p1 + t * d1]
end

function circle_line(c::Pt, r::Float64, p::Pt, d::Pt)
    # |p + t d − c|² = r², d unit
    f = p - c
    b = dot2(f, d)
    disc = b^2 - (dot2(f, f) - r^2)
    disc < 0 && return Pt[]
    s = sqrt(disc)
    s == 0 && return [p + (-b) * d]
    return [p + (-b - s) * d, p + (-b + s) * d]
end

function circle_circle(c1::Pt, r1::Float64, c2::Pt, r2::Float64)
    v = c2 - c1
    D = norm2(v)
    (D == 0 || D > r1 + r2 || D < abs(r1 - r2)) && return Pt[]
    a = (r1^2 - r2^2 + D^2) / (2D)
    h2 = r1^2 - a^2
    h = h2 <= 0 ? 0.0 : sqrt(h2)
    m = c1 + (a / D) * v
    u = Pt(-v.y, v.x) / D
    h == 0 && return [m]
    return [m + h * u, m - h * u]
end

carrier(c::Circle) = c
carrier(a::Arc) = Circle(a.c, a.r)
carrier(l::Line) = l
carrier(s::Segment) = Line(s.a, s.b - s.a)

"""
    intersect_prims(a, b; tol = 1e-12) -> Vector{Pt}

Intersection points of two primitives (circles, arcs, lines, segments).
"""
function intersect_prims(a::Primitive, b::Primitive; tol::Real = 1e-12)
    pts = _intersect(carrier(a), carrier(b))
    return [
        p for p in pts if distance_to(a, p) <= tol * (1 + norm2(p)) &&
        distance_to(b, p) <= tol * (1 + norm2(p))
    ]
end

_intersect(a::Circle, b::Circle) = circle_circle(a.c, a.r, b.c, b.r)
_intersect(a::Circle, b::Line) = circle_line(a.c, a.r, b.p, b.d)
_intersect(a::Line, b::Circle) = circle_line(b.c, b.r, a.p, a.d)
_intersect(a::Line, b::Line) = line_line(a.p, a.d, b.p, b.d)
