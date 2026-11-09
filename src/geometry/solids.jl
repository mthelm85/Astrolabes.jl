# Material shapes (what is left after cutting), built with Clipper2 via Clipper.jl.
#
# A `Shape` is a set of closed contours under the non-zero fill rule as returned by
# Clipper: outer boundaries counter-clockwise, holes clockwise. Curves are discretised
# with a chord tolerance; Clipper works in integers, `CLIPPER_SCALE` per unit.

const CLIPPER_SCALE = 1e7

"Material region: closed contours (outer CCW, holes CW)."
struct Shape
    contours::Vector{Vector{Pt}}
end
Shape() = Shape(Vector{Pt}[])

to_path(pts::AbstractVector{Pt}) = Clipper.Point64[
    Clipper.Point64(round(Int64, p.x * CLIPPER_SCALE), round(Int64, p.y * CLIPPER_SCALE)) for p in pts
]
from_path(path) = Pt[Pt(q.x / CLIPPER_SCALE, q.y / CLIPPER_SCALE) for q in path]
to_paths(s::Shape) = Clipper.Path64[to_path(c) for c in s.contours]
from_paths(ps) = Shape([from_path(p) for p in ps if length(p) >= 3])

"Signed area of a closed contour (positive when counter-clockwise)."
function signed_area(c::AbstractVector{Pt})
    a = 0.0
    n = length(c)
    for i = 1:n
        p, q = c[i], c[mod1(i + 1, n)]
        a += p.x * q.y - q.x * p.y
    end
    return a / 2
end

"Total area of a shape."
shape_area(s::Shape) = sum(signed_area, s.contours; init = 0.0)

ccw(c::Vector{Pt}) = signed_area(c) >= 0 ? c : reverse(c)
cw(c::Vector{Pt}) = signed_area(c) <= 0 ? c : reverse(c)

"Closed polygon approximating the circle within `tol`."
function circle_contour(c::Pt, r::Real; tol::Real)
    n = max(arc_segments(r, 2π, tol), 8)
    return [c + polar(r, 2π * k / n) for k = 0:(n-1)]
end

"Solid disk."
disk_shape(c::Pt, r::Real; tol::Real) = Shape([circle_contour(c, r; tol)])

"Solid annulus between radii `r1 < r2`."
annulus_shape(c::Pt, r1::Real, r2::Real; tol::Real) =
    Shape([circle_contour(c, r2; tol), reverse(circle_contour(c, r1; tol))])

"Solid polygon."
polygon_shape(pts::AbstractVector{Pt}) = Shape([ccw(collect(pts))])

"Bar of width `w` along the segment `a`–`b` (square ends)."
function bar_shape(a::Pt, b::Pt, w::Real)
    d = unit(b - a)
    n = Pt(-d.y, d.x) * (w / 2)
    return polygon_shape([a - n, b - n, b + n, a + n])
end

"Thick version of open primitives (stroke of width `w`, round ends)."
function stroke_shape(prims::AbstractVector{<:Primitive}, w::Real; tol::Real)
    paths = Clipper.Path64[to_path(polyline_points(p; tol)) for p in prims]
    isempty(paths) && return Shape()
    out = Clipper.inflate_paths(
        paths,
        w / 2 * CLIPPER_SCALE,
        Clipper.JoinTypeRound,
        Clipper.EndTypeRound;
        arc_tolerance = tol * CLIPPER_SCALE,
    )
    return from_paths(out)
end

"Union of shapes."
function shape_union(shapes::Shape...)
    paths = reduce(vcat, (to_paths(s) for s in shapes); init = Clipper.Path64[])
    isempty(paths) && return Shape()
    return from_paths(Clipper.union_paths(paths, Clipper.FillRuleNonZero))
end

"Material of `a` with `b` removed."
function shape_difference(a::Shape, b::Shape)
    isempty(b.contours) && return a
    return from_paths(
        Clipper.difference_paths(to_paths(a), to_paths(b), Clipper.FillRuleNonZero),
    )
end

"Material common to `a` and `b`."
shape_intersection(a::Shape, b::Shape) =
    from_paths(Clipper.intersect_paths(to_paths(a), to_paths(b), Clipper.FillRuleNonZero))

"Grow (`d > 0`) or shrink (`d < 0`) a shape by `d` with round joins."
function shape_offset(s::Shape, d::Real; tol::Real)
    isempty(s.contours) && return s
    out = Clipper.inflate_paths(
        to_paths(s),
        d * CLIPPER_SCALE,
        Clipper.JoinTypeRound,
        Clipper.EndTypePolygon;
        arc_tolerance = tol * CLIPPER_SCALE,
    )
    return from_paths(out)
end

"""
    components(s::Shape) -> Vector{Shape}

Connected pieces of material (each an outer contour with its holes).
"""
function components(s::Shape)
    isempty(s.contours) && return Shape[]
    c = Clipper.Clipper64()
    Clipper.add_subject!(c, to_paths(s))
    tree, _ = Clipper.execute_polytree(c, Clipper.ClipTypeUnion, Clipper.FillRuleNonZero)
    out = Shape[]
    function walk(node)
        for ch in Clipper.children(node)
            if Clipper.ishole(ch)
                walk(ch)          # islands inside holes are separate pieces
            else
                cont = [from_path(Clipper.contour(ch))]
                for h in Clipper.children(ch)
                    push!(cont, from_path(Clipper.contour(h)))
                end
                push!(out, Shape(cont))
                for h in Clipper.children(ch)
                    walk(h)
                end
            end
        end
    end
    walk(tree)
    return out
end

"Holes of a single-component shape (contours with negative orientation)."
holes(s::Shape) = [c for c in s.contours if signed_area(c) < 0]
outers(s::Shape) = [c for c in s.contours if signed_area(c) > 0]

"Winding-number point-in-shape test (non-zero rule)."
function point_in_shape(s::Shape, p::Pt)
    w = 0
    for c in s.contours
        n = length(c)
        for i = 1:n
            a, b = c[i], c[mod1(i + 1, n)]
            if a.y <= p.y
                b.y > p.y && cross2(b - a, p - a) > 0 && (w += 1)
            else
                b.y <= p.y && cross2(b - a, p - a) < 0 && (w -= 1)
            end
        end
    end
    return w != 0
end

"Contours of a shape as closed polylines (for cutting)."
contour_prims(s::Shape) = Primitive[Polyline(c, true) for c in s.contours]

"""
    narrowest_loss(s::Shape, w; tol) -> (area_lost, pieces_before, pieces_after)

Morphological opening with a disk of diameter `w`: material thinner than `w` is lost.
If the number of pieces grows, a bridge is thinner than `w`.
"""
function narrowest_loss(s::Shape, w::Real; tol::Real)
    opened = shape_offset(shape_offset(s, -w / 2; tol), w / 2; tol)
    lost = shape_area(s) - shape_area(opened)
    return (
        area_lost = max(lost, 0.0),
        before = length(components(s)),
        after = length(components(opened)),
    )
end

"Translate / rotate / scale a shape."
translate(s::Shape, v::Pt) = Shape([[p + v for p in c] for c in s.contours])
rotate(s::Shape, θ::Real) = Shape([[rotate(p, θ) for p in c] for c in s.contours])
scale(s::Shape, k::Real) = Shape([[k * p for p in c] for c in s.contours])
