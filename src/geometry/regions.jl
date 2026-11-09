# Clipping primitives to regions, and rigid transforms of primitives.

"A region of the plane that primitives can be clipped to."
abstract type Region end

"The closed disk with centre `c` and radius `r`."
struct Disk <: Region
    c::Pt
    r::Float64
end

"Everything outside the open disk with centre `c` and radius `r`."
struct OutsideDisk <: Region
    c::Pt
    r::Float64
end

"The closed half-plane `{x : (x − p)·n ≥ 0}`."
struct HalfPlane <: Region
    p::Pt
    n::Pt
end

const REGION_EPS = 1e-12

inside(D::Disk, p::Pt) = norm2(p - D.c) <= D.r + REGION_EPS
inside(D::OutsideDisk, p::Pt) = norm2(p - D.c) >= D.r - REGION_EPS
inside(H::HalfPlane, p::Pt) = dot2(p - H.p, H.n) >= -REGION_EPS
inside(D::Circle, p::Pt) = inside(Disk(D.c, D.r), p)

boundary(D::Union{Disk,OutsideDisk}) = Circle(D.c, D.r)
boundary(H::HalfPlane) = Line(H.p, Pt(-H.n.y, H.n.x))

"""
    clip(prim, region) -> Vector{Primitive}

The parts of `prim` inside `region` (a [`Disk`](@ref), [`OutsideDisk`](@ref) or
[`HalfPlane`](@ref)). Infinite lines can only be clipped to a `Disk`.
"""
function clip(c::Circle, R::Region)
    pts = _intersect(c, carrier(boundary(R)))
    if length(pts) < 2
        # no proper crossing: the circle is entirely in or out (test a point away
        # from any tangency)
        probe = isempty(pts) ? c.c + Pt(c.r, 0) : 2c.c - pts[1]
        return inside(R, probe) ? Primitive[c] : Primitive[]
    end
    return clip(Arc(c.c, c.r, 0.0, 2π), R)
end

function clip(a::Arc, R::Region)
    pts = _intersect(carrier(a), carrier(boundary(R)))
    cuts = sort!([wrap_from(angle_of(p - a.c), a.θ1) for p in pts])
    bounds = [a.θ1; filter(t -> a.θ1 < t < a.θ2, cuts); a.θ2]
    out = Primitive[]
    for i = 1:(length(bounds)-1)
        t1, t2 = bounds[i], bounds[i+1]
        t2 - t1 < 1e-14 && continue
        inside(R, arc_point(a, (t1 + t2) / 2)) && push!(out, Arc(a.c, a.r, t1, t2))
    end
    return merge_arcs(out)
end

# join the two arcs that meet across the θ1/θ2 seam of a full circle
function merge_arcs(arcs::Vector{Primitive})
    length(arcs) == 2 || return arcs
    a, b = arcs[1]::Arc, arcs[2]::Arc
    isapprox(b.θ2, a.θ1 + 2π; atol = 1e-13) &&
        return Primitive[Arc(b.c, b.r, b.θ1, a.θ2 + 2π)]
    return arcs
end

function clip(l::Line, D::Disk)
    pts = circle_line(D.c, D.r, l.p, l.d)
    length(pts) == 2 || return Primitive[]
    return Primitive[Segment(pts[1], pts[2])]
end
clip(::Line, ::Region) = throw(ArgumentError("clip infinite lines to a Disk first"))

function clip(s::Segment, R::Region)
    L = norm2(s.b - s.a)
    L == 0 && return inside(R, s.a) ? Primitive[s] : Primitive[]
    d = (s.b - s.a) / L
    pts = _intersect(Line(s.a, d), carrier(boundary(R)))
    ts = sort!([t for t in (dot2(p - s.a, d) for p in pts) if 0 < t < L])
    bounds = [0.0; ts; L]
    out = Primitive[]
    for i = 1:(length(bounds)-1)
        t1, t2 = bounds[i], bounds[i+1]
        t2 - t1 <= 1e-14 && continue
        inside(R, s.a + ((t1 + t2) / 2) * d) &&
            push!(out, Segment(s.a + t1 * d, s.a + t2 * d))
    end
    # rejoin pieces split at a tangency
    length(out) == 2 &&
        isapprox(out[1].b, out[2].a; atol = 1e-13) &&
        return Primitive[Segment(out[1].a, out[2].b)]
    return out
end

function clip(pl::Polyline, R::Region)
    out = Primitive[]
    run = Pt[]
    pts = pl.closed ? [pl.pts; pl.pts[1]] : pl.pts
    for i = 1:(length(pts)-1)
        pieces = clip(Segment(pts[i], pts[i+1]), R)
        if isempty(pieces)
            length(run) >= 2 && push!(out, Polyline(run))
            run = Pt[]
            continue
        end
        for seg in pieces
            seg = seg::Segment
            if !isempty(run) && isapprox(run[end], seg.a; atol = 1e-13)
                push!(run, seg.b)
            else
                length(run) >= 2 && push!(out, Polyline(run))
                run = [seg.a, seg.b]
            end
        end
    end
    length(run) >= 2 && push!(out, Polyline(run))
    return out
end

clip(prims::AbstractVector{<:Primitive}, R::Region) =
    reduce(vcat, (clip(p, R) for p in prims); init = Primitive[])

"""
    clip_to_disk(prim, D::Circle) -> Vector{Primitive}

The parts of `prim` that lie inside the closed disk bounded by `D`.
"""
clip_to_disk(p, D::Circle) = clip(p, Disk(D.c, D.r))

# ---------------------------------------------------------------- transforms

"Rotate about the origin by `θ` radians (counter-clockwise)."
rotate(p::Pt, θ::Real) = (s = sin(θ); c = cos(θ); Pt(c * p.x - s * p.y, s * p.x + c * p.y))
rotate(c::Circle, θ::Real) = Circle(rotate(c.c, θ), c.r)
rotate(a::Arc, θ::Real) = Arc(rotate(a.c, θ), a.r, a.θ1 + θ, a.θ2 + θ)
rotate(l::Line, θ::Real) = Line(rotate(l.p, θ), rotate(l.d, θ))
rotate(s::Segment, θ::Real) = Segment(rotate(s.a, θ), rotate(s.b, θ))
rotate(pl::Polyline, θ::Real) = Polyline([rotate(p, θ) for p in pl.pts], pl.closed)

"Translate by the vector `v`."
translate(p::Pt, v::Pt) = p + v
translate(c::Circle, v::Pt) = Circle(c.c + v, c.r)
translate(a::Arc, v::Pt) = Arc(a.c + v, a.r, a.θ1, a.θ2)
translate(l::Line, v::Pt) = Line(l.p + v, l.d)
translate(s::Segment, v::Pt) = Segment(s.a + v, s.b + v)
translate(pl::Polyline, v::Pt) = Polyline([p + v for p in pl.pts], pl.closed)

"Scale about the origin by `k > 0`."
scale(p::Pt, k::Real) = k * p
scale(c::Circle, k::Real) = Circle(k * c.c, k * c.r)
scale(a::Arc, k::Real) = Arc(k * a.c, k * a.r, a.θ1, a.θ2)
scale(l::Line, k::Real) = Line(k * l.p, l.d)
scale(s::Segment, k::Real) = Segment(k * s.a, k * s.b)
scale(pl::Polyline, k::Real) = Polyline([k * p for p in pl.pts], pl.closed)

"Mirror in the y axis (x → −x)."
mirror_x(p::Pt) = Pt(-p.x, p.y)
mirror_x(c::Circle) = Circle(mirror_x(c.c), c.r)
mirror_x(a::Arc) = Arc(mirror_x(a.c), a.r, π - a.θ2, π - a.θ1)
mirror_x(l::Line) = Line(mirror_x(l.p), mirror_x(l.d))
mirror_x(s::Segment) = Segment(mirror_x(s.a), mirror_x(s.b))
mirror_x(pl::Polyline) = Polyline([mirror_x(p) for p in pl.pts], pl.closed)

for f in (:rotate, :translate, :scale)
    @eval $f(ps::AbstractVector{<:Primitive}, x) = Primitive[$f(p, x) for p in ps]
end
mirror_x(ps::AbstractVector{<:Primitive}) = Primitive[mirror_x(p) for p in ps]

"""
    polyline_points(prim; tol) -> Vector{Pt}

Points along `prim` such that the chords deviate from it by at most `tol`.
"""
function polyline_points(a::Arc; tol::Real)
    n = arc_segments(a.r, a.θ2 - a.θ1, tol)
    return [arc_point(a, a.θ1 + (a.θ2 - a.θ1) * k / n) for k = 0:n]
end
function polyline_points(c::Circle; tol::Real)
    n = arc_segments(c.r, 2π, tol)
    return [c.c + polar(c.r, 2π * k / n) for k = 0:n]
end
polyline_points(s::Segment; tol::Real = 0) = [s.a, s.b]
polyline_points(pl::Polyline; tol::Real = 0) = pl.closed ? [pl.pts; pl.pts[1]] : pl.pts

function arc_segments(r::Real, span::Real, tol::Real)
    r <= tol && return max(1, ceil(Int, span / (π / 2)))
    step = 2acos(1 - tol / r)
    return max(1, ceil(Int, span / step))
end

"Length of a primitive."
prim_length(c::Circle) = 2π * c.r
prim_length(a::Arc) = a.r * (a.θ2 - a.θ1)
prim_length(s::Segment) = norm2(s.b - s.a)
prim_length(pl::Polyline) =
    sum(norm2(b - a) for (a, b) in zip(pl.pts, pl.pts[2:end]); init = 0.0) +
    (pl.closed ? norm2(pl.pts[1] - pl.pts[end]) : 0.0)
