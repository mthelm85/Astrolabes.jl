# The rule (front) and the alidade with its sight vanes (back).
#
# Both are counterchanged, as on historical instruments: one straight fiducial edge runs
# the full length through the pivot, and the bar lies on one side of it in the upper half
# and on the other side in the lower half. Readings are taken where the edge crosses a
# scale, with the scale's ticks in plain view beside it, so the parts work in opaque
# material (brass, 3D prints) as well as in clear acrylic. The halves are point-symmetric
# about the pivot, so each part balances on its pin: hung by the throne, the instrument
# does not tilt whichever way the rule or alidade is turned.

"""
    counterchanged_bar(L, w, tip, hub_r; tol) -> Shape

A bar of length `2L` whose fiducial edge is the line `x = 0`. The upper half (`y > 0`)
lies on `0 ≤ x ≤ w`, the lower half on `−w ≤ x ≤ 0`; each end tapers over `tip` to a
point on the edge, and a round hub of radius `hub_r` joins the halves at the pivot. The
shape is symmetric under a half turn about the pivot.
"""
counterchanged_bar(L, w, tip, hub_r; tol) = shape_union(
    polygon_shape([Pt(0, 0), Pt(w, 0), Pt(w, L - tip), Pt(0, L)]),
    polygon_shape([Pt(0, 0), Pt(0, -L), Pt(-w, -L + tip), Pt(-w, 0)]),
    disk_shape(Pt(0, 0), hub_r; tol),
)

# hub radius joining the two halves: wide enough to carry the bar across the pivot
bar_hub(pin_radius, w, mm) = pin_radius + max(mm(3.0), 0.5w)

"""
    Rule

The front rule: a counterchanged bar turning about the centre. Its fiducial edge
(`fiducial`, the line `x = 0`) passes through the centre and is the reading line. The
upper half carries a declination scale: the tick for δ lies at the plate radius of
declination δ.
"""
struct Rule
    half_length::Float64
    width::Float64
    solid::Shape
    fiducial::Segment
    ticks::Vector{Tuple{Float64,Segment}}
    labels::Vector{Label}
end

function Rule(
    P::Stereographic,
    ε;
    half_length,
    scale,
    pin_radius,
    width_mm = 10.0,
    label_h,
    min_space,
    tol = 2e-5,
)
    s = scale
    mm(x) = x / s
    w = mm(width_mm)
    hub_r = bar_hub(pin_radius, w, mm)
    solid = shape_difference(
        counterchanged_bar(half_length, w, mm(8), hub_r; tol),
        disk_shape(Pt(0, 0), pin_radius; tol),
    )
    fid = Segment(Pt(0, -half_length), Pt(0, half_length))
    r0 = hub_r + mm(0.5)
    lo, hi = outer_tropic(P, ε), 80.0
    δs = P.hemisphere === :north ? collect(ceil(lo):1.0:hi) : collect(floor(-lo):-1.0:-hi)
    ticks = Tuple{Float64,Segment}[]
    labels = Label[]
    x_text = 0.38w                          # numbers start beyond the longest tick
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
        # ticks run in from the fiducial edge, so they meet the reading line
        push!(ticks, (δ, Segment(Pt(0, r), Pt(L, r))))
        if major
            str = string(round(Int, δ))
            hfit = (w - x_text - mm(1.0)) / text_width(str, 1.0)
            push!(labels, Label(str, Pt(x_text, r), min(label_h, hfit); halign = :left))
        end
    end
    return Rule(half_length, w, solid, fid, ticks, labels)
end

"""
    Alidade

The sighting rule on the back: a counterchanged bar like the [`Rule`](@ref), whose
fiducial edge passes through the centre and is the reading line. Two sight vanes stand
on it at `±vane_radius`, in a ring of width `vane_band` on the back where nothing is
engraved. Only there the bar widens into a small pad that spans the edge, so each vane,
no wider than the bar, stands centred on the fiducial line with its pinhole over it: the
line of sight *is* the reading line, and the pads cover nothing that is ever read.

`vane` is the vane in its own frame (x across the bar, y up from the bar's face, tab
below `y = 0`), `vane_holes` its pinhole, and `vane_mounts` the alidade-frame position of
each vane's origin with its turn about the alidade's normal.
"""
struct Alidade
    half_length::Float64
    width::Float64
    solid::Shape
    fiducial::Vector{Primitive}
    vane::Shape
    vane_holes::Vector{Pt}
    vane_mounts::Vector{Tuple{Pt,Float64}}
    vane_radius::Float64
end

function Alidade(;
    half_length,
    scale,
    pin_radius,
    thickness_mm,
    vane_radius = 0.62half_length,
    vane_band = 0.0,
    width_mm = 10.0,
    tab_mm = 6.0,
    vane_height_mm = 16.0,
    slot_clearance_mm = 0.1,
    pinhole_mm = 1.2,
    tol = 2e-5,
)
    s = scale
    mm(x) = x / s
    w = mm(width_mm)
    t = mm(thickness_mm + slot_clearance_mm)
    tab = min(mm(tab_mm), 0.6w)
    hw = w / 2
    rv = vane_radius
    # pads: the bar widened across the edge, only within the blank vane ring
    # (a strip of the ring itself, so not even a corner reaches past it)
    # 0.1 mm inside it, as the polygon for a circle lies slightly outside the circle
    ph = max(vane_band, t + mm(2.0)) / 2 - mm(0.1)
    pad = shape_intersection(
        annulus_shape(Pt(0, 0), rv - ph, rv + ph; tol),
        rect_shape(-hw, 0, hw, rv + 2ph),
    )
    bar = shape_union(
        counterchanged_bar(half_length, w, mm(10), bar_hub(pin_radius, w, mm); tol),
        pad,
        rotate(pad, π),
    )
    for y in (rv, -rv)
        bar = shape_difference(bar, rect_shape(-tab / 2, y - t / 2, tab / 2, y + t / 2))
    end
    solid = shape_difference(bar, disk_shape(Pt(0, 0), pin_radius; tol))
    fid = Primitive[Segment(Pt(0, -half_length), Pt(0, half_length))]
    # vane: a plate as wide as the bar, centred on the fiducial line, on a centred tab
    vh = mm(vane_height_mm)
    th = mm(thickness_mm)
    vane = shape_union(rect_shape(-hw, 0, hw, vh), rect_shape(-tab / 2, -th, tab / 2, 0.0))
    hole = Pt(0, 0.72vh)
    vane = shape_difference(vane, disk_shape(hole, mm(pinhole_mm / 2); tol))
    mounts = [(Pt(0, rv), 0.0), (Pt(0, -rv), Float64(π))]
    return Alidade(half_length, w, solid, fid, vane, [hole], mounts, rv)
end
