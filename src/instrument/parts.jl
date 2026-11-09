# Physical parts: material (cut) plus engraved lines and labels.

"""
    Part(name, solid, engrave, score, labels; quantity = 1, face = :front)

One piece to fabricate. `solid` is the material (its contours are the cut paths),
`engrave` and `score` are lines on its surface, `labels` engraved text. All geometry is
in plate units; multiply by the astrolabe's `scale` for millimetres.
"""
struct Part
    name::String
    solid::Shape
    engrave::Vector{Primitive}
    score::Vector{Primitive}
    labels::Vector{Label}
    quantity::Int
    face::Symbol
end
Part(name, solid, engrave, score, labels; quantity::Integer = 1, face::Symbol = :front) =
    Part(
        String(name),
        solid,
        Primitive[engrave...],
        Primitive[score...],
        Label[labels...],
        quantity,
        face,
    )

"""
    mater_outline(r, throne_width, throne_height, hole_r; tol) -> Shape

A disk of radius `r` with a throne (kursi) at the top carrying a hole of radius `hole_r`
for the shackle.
"""
function mater_outline(r, tw, th, hole_r; tol)
    O = Pt(0, 0)
    base_y = sqrt(r^2 - (tw / 2)^2) - tw * 0.15
    top = Pt(0, r + th - tw * 0.32)
    body = polygon_shape([
        Pt(-tw / 2, base_y),
        Pt(tw / 2, base_y),
        Pt(tw * 0.32, top.y),
        Pt(-tw * 0.32, top.y),
    ])
    crown = disk_shape(top, tw * 0.32; tol)
    s = shape_union(disk_shape(O, r; tol), body, crown)
    return shape_difference(s, disk_shape(top, hole_r; tol)), top
end

"Raise every label to at least height `h` (keeping its anchor)."
at_least(labels, h::Real) = Label[
    l.height < h ? Label(l.text, l.pos, h, l.angle, l.halign, l.valign) : l for l in labels
]

# points every `step` along a polyline; `keep[i]` marks the original vertices
function densify(pts::Vector{Pt}, step::Real)
    out = Pt[pts[1]]
    keep = Bool[true]
    for i = 2:length(pts)
        a, b = pts[i-1], pts[i]
        k = max(1, ceil(Int, norm2(b - a) / step))
        for j = 1:k
            push!(out, a + (j / k) * (b - a))
            push!(keep, j == k)
        end
    end
    return out, keep
end

# the piece of `p` covered by a run of its densified points, as the same kind of
# primitive where possible (an arc stays an arc, a segment a segment)
function trimmed(p::Union{Arc,Circle}, run::Vector{Pt}, ::Vector{Bool})
    θ0 = p isa Arc ? p.θ1 : 0.0
    t(q) = θ0 + mod(angle_of(q - p.c) - θ0, 2π)
    θa, θb = t(run[1]), t(run[end])
    θb <= θa && (θb += 2π)
    return Arc(p.c, p.r, θa, θb)
end
trimmed(::Segment, run::Vector{Pt}, ::Vector{Bool}) = Segment(run[1], run[end])
function trimmed(::Primitive, run::Vector{Pt}, keep::Vector{Bool})
    pts = [q for (i, q) in enumerate(run) if keep[i] || i == 1 || i == length(run)]
    return Polyline(pts, false)
end

"""
    fit_engraving(prims, solid, margin; step, tol) -> Vector{Primitive}

Keep engraved lines at least `margin` inside the material: primitives that lie wholly
inside the shrunken solid are kept as they are, others are cut (to within `step`) into
the pieces that lie inside it, arcs as arcs and segments as segments.
"""
function fit_engraving(prims, solid::Shape, margin::Real; step::Real, tol::Real = 2e-5)
    inner = margin > 0 ? shape_offset(solid, -margin; tol) : solid
    out = Primitive[]
    for p in prims
        pts, keep = densify(polyline_points(p; tol), step)
        ins = [point_in_shape(inner, q) for q in pts]
        if all(ins)
            push!(out, p)
            continue
        end
        run, rkeep = Pt[], Bool[]
        function flush!()
            length(run) >= 2 && push!(out, trimmed(p, run, rkeep))
            empty!(run)
            empty!(rkeep)
        end
        for (q, ok, k) in zip(pts, ins, keep)
            if ok
                push!(run, q)
                push!(rkeep, k)
            else
                flush!()
            end
        end
        flush!()
    end
    return out
end

"Rectangle with corners `(x1, y1)` and `(x2, y2)`."
rect_shape(x1, y1, x2, y2) = polygon_shape([Pt(x1, y1), Pt(x2, y1), Pt(x2, y2), Pt(x1, y2)])
