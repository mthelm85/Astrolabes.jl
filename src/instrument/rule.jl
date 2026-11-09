# The rule (front) and the alidade with its sight vanes (back).

"""
    Rule

The front rule: a bar turning about the centre whose centre line (the fiducial edge) is
the reading line. It carries a declination scale: the tick for δ lies at the plate
radius of declination δ.
"""
struct Rule
    half_length::Float64
    width::Float64
    solid::Shape
    fiducial::Segment
    ticks::Vector{Tuple{Float64,Segment}}
    labels::Vector{Label}
end

pointed_bar(L, w, tip) = polygon_shape([
    Pt(-w / 2, -L + tip),
    Pt(0, -L),
    Pt(w / 2, -L + tip),
    Pt(w / 2, L - tip),
    Pt(0, L),
    Pt(-w / 2, L - tip),
])

function Rule(
    P::Stereographic,
    ε;
    half_length,
    scale,
    pin_radius,
    width_mm = 8.0,
    label_h,
    min_space,
    tol = 2e-5,
)
    s = scale
    mm(x) = x / s
    w = mm(width_mm)
    solid = shape_difference(
        pointed_bar(half_length, w, mm(8)),
        disk_shape(Pt(0, 0), pin_radius; tol),
    )
    r0 = pin_radius + mm(1.0)
    fid = Segment(Pt(0, r0), Pt(0, half_length - mm(1)))
    lo, hi = outer_tropic(P, ε), 80.0
    δs = P.hemisphere === :north ? collect(ceil(lo):1.0:hi) : collect(floor(-lo):-1.0:-hi)
    ticks = Tuple{Float64,Segment}[]
    labels = Label[]
    for δ in δs
        r = radius_of_dec(P, δ)
        r > r0 || continue
        major = round(Int, δ) % 10 == 0
        L = (major ? 0.32 : round(Int, δ) % 5 == 0 ? 0.24 : 0.15) * w
        # skip minor ticks that would crowd
        if !major &&
           !isempty(ticks) &&
           abs(r - norm2(ticks[end][2].a)) * s < min_space + 0.2
            continue
        end
        push!(ticks, (δ, Segment(Pt(0, r), Pt(L, r))))
        # numbers on the other side of the fiducial line from the ticks
        if major
            str = string(round(Int, δ))
            hfit = (w / 2 - mm(1.0)) / text_width(str, 1.0)
            push!(labels, Label(str, Pt(-mm(0.5), r), min(label_h, hfit); halign = :right))
        end
    end
    return Rule(half_length, w, solid, fid, ticks, labels)
end

"""
    Alidade

The sighting rule on the back. Two vanes stand in slots; the line through their pinholes
is parallel to the fiducial centre line.
"""
struct Alidade
    half_length::Float64
    width::Float64
    solid::Shape
    fiducial::Vector{Primitive}
    vane::Shape
    vane_holes::Vector{Pt}
    slot_positions::Vector{Float64}
end

function Alidade(;
    half_length,
    scale,
    pin_radius,
    thickness_mm,
    width_mm = 10.0,
    tab_mm = 6.0,
    vane_height_mm = 16.0,
    slot_clearance_mm = 0.1,
    tol = 2e-5,
)
    s = scale
    mm(x) = x / s
    w = mm(width_mm)
    t = mm(thickness_mm + slot_clearance_mm)
    tab = mm(tab_mm)
    ys = [-0.62half_length, 0.62half_length]
    bar = pointed_bar(half_length, w, mm(10))
    for y in ys
        bar = shape_difference(bar, rect_shape(-tab / 2, y - t / 2, tab / 2, y + t / 2))
    end
    solid = shape_difference(bar, disk_shape(Pt(0, 0), pin_radius; tol))
    # fiducial centre line, broken where the vane slots cut through
    edges = sort([
        -half_length + mm(1),
        -pin_radius - mm(1),
        pin_radius + mm(1),
        half_length - mm(1),
    ])
    fid = Primitive[]
    for (y1, y2) in ((edges[1], edges[2]), (edges[3], edges[4]))
        cuts = sort([y for y in ys if y1 < y < y2])
        a = y1
        for y in cuts
            push!(fid, Segment(Pt(0, a), Pt(0, y - t / 2 - mm(0.5))))
            a = y + t / 2 + mm(0.5)
        end
        push!(fid, Segment(Pt(0, a), Pt(0, y2)))
    end
    # vane: a plate standing on a tab that fits the slot; pinhole on the centre line
    vw, vh = w * 0.9, mm(vane_height_mm)
    th = mm(thickness_mm)
    vane = shape_union(
        rect_shape(-vw / 2, 0, vw / 2, vh),
        rect_shape(-tab / 2, -th, tab / 2, 0.0),
    )
    hole = Pt(0, 0.72vh)
    vane = shape_difference(vane, disk_shape(hole, mm(0.6); tol))
    return Alidade(half_length, w, solid, fid, vane, [hole], ys)
end
