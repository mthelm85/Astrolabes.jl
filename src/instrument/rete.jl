# The rete: a pierced star map that turns over the plate.
#
# Rete frame: the rete as it lies at local sidereal time 0, i.e. with the vernal equinox
# on the upper meridian. A star at right ascension α then has hour angle H = −α. Turning
# the rete to sidereal time θ rotates it by `rete_angle(P, θ)`.

"""
    ReteStyle(; kwargs...)

Dimensions of the rete in millimetres: `rim_width`, `ecliptic_width` (the graduated
band), `tropic_width`, `bar_width`, `hub_radius`, `pointer_width`, `tip_length`,
`label_height`, plus `names` (`:iau` or `:traditional`) and `equator_ring`.
"""
Base.@kwdef struct ReteStyle
    rim_width::Float64 = 3.0
    ecliptic_width::Float64 = 7.0
    tropic_width::Float64 = 2.2
    bar_width::Float64 = 2.6
    hub_radius::Float64 = 6.5
    pointer_width::Float64 = 2.8
    tip_length::Float64 = 4.0
    label_height::Float64 = 1.6
    names::Symbol = :iau
    equator_ring::Bool = false
end

"A star on the rete: a pierced pointer whose `tip` marks the star, or an engraved `:marker`."
struct RetePointer
    star::Star
    ra::Float64
    dec::Float64
    tip::Pt
    kind::Symbol
    labelled::Bool
end

"A graduation of the ecliptic ring: `outer` lies on the ecliptic at longitude `λ`."
struct EclipticTick
    λ::Float64
    outer::Pt
    inner::Pt
end

"""
    Rete

The rete for one epoch: the `ecliptic` circle (the reading edge of the zodiac band),
its graduations, star pointers, and the cut `solid`. Geometry is in plate units (R = 1)
in the rete frame (sidereal time 0); `scale` is millimetres per unit.
"""
struct Rete
    epoch::Epoch
    projection::Stereographic
    obliquity::Float64
    scale::Float64
    radius::Float64
    pin_radius::Float64
    style::ReteStyle
    ecliptic::Circle
    band_inner::Float64
    ticks::Vector{EclipticTick}
    pointers::Vector{RetePointer}
    skipped::Vector{Pair{String,String}}
    solid::Shape
    engrave::Vector{Primitive}
    labels::Vector{Label}
end

"Angle (radians) by which the rete turns at sidereal time `θ` (degrees)."
rete_angle(P::Stereographic, θ::Real) = P.hemisphere === :north ? -deg2rad(θ) : deg2rad(θ)

"Equatorial coordinates (degrees) of ecliptic longitude `λ` for obliquity `ε`."
function ecliptic_to_equatorial(λ::Real, ε::Real)
    α = mod(atand(cosd(ε) * sind(λ), cosd(λ)), 360)
    δ = asind(sind(ε) * sind(λ))
    return (ra = α, dec = δ)
end

"Rete-frame position of ecliptic longitude `λ`."
ecliptic_point(P::Stereographic, ε::Real, λ::Real) =
    (q = ecliptic_to_equatorial(λ, ε); project(P, -q.ra, q.dec))

"Rete-frame position of a star with right ascension `α`, declination `δ`."
star_point(P::Stereographic, α::Real, δ::Real) = project(P, -α, δ)

"""
    ecliptic_circle(P, ε) -> Circle

The projected ecliptic. The solstices are diametrically opposite on the circle and lie
on the x axis of the rete frame, so the circle has them as the ends of a diameter.
"""
function ecliptic_circle(P::Stereographic, ε::Real)
    a = ecliptic_point(P, ε, 90.0)
    b = ecliptic_point(P, ε, 270.0)
    return Circle((a + b) / 2, norm2(a - b) / 2)
end

const ZODIAC =
    ("ARI", "TAU", "GEM", "CNC", "LEO", "VIR", "LIB", "SCO", "SGR", "CAP", "AQR", "PSC")

# nearest point on the boundary of a shape
function nearest_boundary_point(s::Shape, p::Pt)
    best, bd = p, Inf
    for c in s.contours
        n = length(c)
        for i = 1:n
            a, b = c[i], c[mod1(i + 1, n)]
            v = b - a
            L2 = dot2(v, v)
            t = L2 == 0 ? 0.0 : clamp(dot2(p - a, v) / L2, 0.0, 1.0)
            q = a + t * v
            d = norm2(p - q)
            d < bd && ((best, bd) = (q, d))
        end
    end
    return best, bd
end

# distance from p along unit direction d to the first crossing of the shape's boundary
function ray_hit(s::Shape, p::Pt, d::Pt)
    best = Inf
    for c in s.contours
        n = length(c)
        for i = 1:n
            a, b = c[i], c[mod1(i + 1, n)]
            v = b - a
            den = cross2(d, v)
            abs(den) < 1e-15 && continue
            w = a - p
            t = cross2(w, v) / den
            u = cross2(w, d) / den
            (t > 0 && -1e-12 <= u <= 1 + 1e-12) && (best = min(best, t))
        end
    end
    return best
end

upright(θ) = (θ = mod(θ + π, 2π) - π;
abs(θ) > π / 2 + 1e-9 ? θ - copysign(π, θ) : θ)

"""
    Rete(epoch, projection; stars, scale, style, pin_radius, clearance, min_feature, tol)

Build the rete. `scale` is millimetres per plate unit; `style` dimensions, `clearance`
(gap to the limb) and `min_feature` are in millimetres. Stars outside the usable annulus
or whose pointer would cover a brighter star's tip are skipped (listed in `skipped`).
"""
function Rete(
    epoch::Epoch,
    P::Stereographic;
    stars::Vector{Star} = catalog_stars(:default),
    scale::Real,
    style::ReteStyle = ReteStyle(),
    pin_radius::Real = 1.6,
    clearance::Real = 0.3,
    min_feature::Real = 0.3,
    tol::Real = 2e-5,
)
    ε = obliquity(epoch)
    s = Float64(scale)
    mm(x) = x / s
    r_out = limb_radius(P, ε) - mm(clearance)
    r_in = radius_of_dec(P, inner_tropic(P, ε))
    E = ecliptic_circle(P, ε)
    O = Pt(0, 0)
    band = mm(style.ecliptic_width)
    rete_disk = disk_shape(O, r_out; tol)
    parts = Shape[
        annulus_shape(O, r_out - mm(style.rim_width), r_out + mm(1); tol),
        annulus_shape(E.c, E.r - band, E.r; tol),
        annulus_shape(
            O,
            r_in - mm(style.tropic_width) / 2,
            r_in + mm(style.tropic_width) / 2;
            tol,
        ),
        bar_shape(Pt(-r_out, 0), Pt(r_out, 0), mm(style.bar_width)),
        bar_shape(Pt(0, -r_in), Pt(0, r_in), mm(style.bar_width)),
        disk_shape(O, mm(style.hub_radius); tol),
    ]
    style.equator_ring && push!(
        parts,
        annulus_shape(
            O,
            P.R - mm(style.tropic_width) / 2,
            P.R + mm(style.tropic_width) / 2;
            tol,
        ),
    )
    structure = shape_intersection(shape_union(parts...), rete_disk)
    solid = structure
    engrave = Primitive[]
    labels = Label[]

    # ecliptic graduations, thinned where they would crowd
    ticks = EclipticTick[]
    spacing(step) = minimum(
        norm2(ecliptic_point(P, ε, λ + step) - ecliptic_point(P, ε, λ)) * s for
        λ = 0:step:359
    )
    gap = min_feature + 0.15
    minor = spacing(1) >= gap ? 1 : spacing(2) >= gap ? 2 : 5
    for λ = 0:minor:359
        len = λ % 30 == 0 ? 1.0 : λ % 10 == 0 ? 0.45 : λ % 5 == 0 ? 0.33 : 0.22
        e = ecliptic_point(P, ε, λ)
        inward = unit(E.c - e)
        push!(ticks, EclipticTick(λ, e, e + (len * band) * inward))
    end

    # star pointers, brightest first
    pointers = RetePointer[]
    skipped = Pair{String,String}[]
    r_max = r_out - mm(style.rim_width) - mm(0.5)
    r_min = pin_radius / s + mm(1.2)
    w = mm(style.pointer_width)
    tip = mm(style.tip_length)
    h = min(mm(style.label_height), 0.62w)
    max_len = 0.45r_out
    mark_r = mm(0.6)
    clear = mm(0.4)                      # engraving-to-engraving clearance
    label_polys = Shape[]                # bodies that carry a name
    label_boxes = Shape[]                # the names themselves
    markers = Pt[]
    notches = Shape[]
    notch_tips = Pt[]
    near_marker(sh::Shape) =
        any(m -> point_in_shape(shape_offset(sh, mark_r + clear; tol), m), markers)
    for st in sort(stars; by = x -> isnan(x.vmag) ? 99.0 : x.vmag)
        q = precess_to(st, epoch)
        T = star_point(P, q.ra, q.dec)
        r = norm2(T)
        if !(r_min <= r <= r_max)
            push!(skipped, st.name => "outside the rete")
            continue
        end
        if !point_in_shape(structure, T) && point_in_shape(solid, T)
            push!(skipped, st.name => "too close to a brighter star")
            continue
        end
        if point_in_shape(structure, T)
            # under the structure: engrave a marker if it sits well inside the material,
            # otherwise cut a small V-notch whose apex is the star
            Qb, d = nearest_boundary_point(structure, T)
            hits_label = any(
                b -> point_in_shape(shape_offset(b, mark_r + clear; tol), T),
                label_boxes,
            )
            if d < mm(1.0)
                dir = d < 1e-9 ? unit(T) : unit(Qb - T)
                if dot2(dir, -T) > 0 && norm2(T) < mm(style.hub_radius) + mm(1)
                    push!(skipped, st.name => "on the hub")
                    continue
                end
                n = Pt(-dir.y, dir.x)
                edge = T + (d + mm(0.6)) * dir
                push!(notches, polygon_shape([T, edge + mm(1.0) * n, edge - mm(1.0) * n]))
                push!(notch_tips, T)
                push!(pointers, RetePointer(st, q.ra, q.dec, T, :notch, false))
            elseif hits_label || any(m -> norm2(m - T) < 2mark_r + clear, markers)
                push!(skipped, st.name => "marker would cover an engraved name")
            else
                push!(pointers, RetePointer(st, q.ra, q.dec, T, :marker, false))
                push!(markers, T)
            end
            continue
        end
        if any(p -> norm2(p.tip - T) < w, pointers)
            push!(skipped, st.name => "too close to a brighter star")
            continue
        end
        name =
            style.names === :traditional ?
            (t = traditional_name(st); isempty(t) ? st.name : t) : st.name
        tw = text_width(font_text(name), h)
        need = tip + mm(1.5) + tw
        body_of(d, L) = (
            n = Pt(-d.y, d.x) * (w / 2);
            endp = T + (L + mm(0.6)) * d;
            L > tip ? [T, T + tip * d + n, endp + n, endp - n, T + tip * d - n] :
            [T, endp + n, endp - n]
        )
        clashes(poly) =
            any(p -> point_in_shape(poly, p.tip), pointers) ||
            any(lp -> shape_area(shape_intersection(lp, poly)) > 0, label_polys)
        # candidate directions: the nearest structure first, then a fan of rays; take the
        # shortest open run that can carry the name
        Q, L0 = nearest_boundary_point(structure, T)
        d0 = unit(Q - T)
        best = nothing
        for k = 0:71
            d = rotate(d0, 2π * k / 72)
            # the name must lie where both edges of the body are still clear of the
            # structure; the body runs on until both edges have met it
            n = Pt(-d.y, d.x) * (w / 2)
            h1, h2 = ray_hit(structure, T + n, d), ray_hit(structure, T - n, d)
            Lc, L = min(h1, h2), max(h1, h2)
            (Lc < need || L > max_len || !isfinite(L) || L - Lc > 3w) && continue
            poly = polygon_shape(body_of(d, L))
            clashes(poly) && continue
            lab = Label(
                name,
                T + (tip + mm(0.5) + (Lc - tip - mm(1.5)) / 2) * d,
                h;
                angle = upright(angle_of(d)),
            )
            box = polygon_shape(label_box(lab))
            near_marker(box) && continue
            (best === nothing || L < best[2]) && (best = (d, L, poly, lab, box))
        end
        if best !== nothing
            d, L, poly, lab, box = best
            push!(labels, lab)
            push!(label_polys, poly)
            push!(label_boxes, box)
            labelled = true
        else
            poly = polygon_shape(body_of(d0, L0))
            if clashes(poly)
                push!(skipped, st.name => "too close to a brighter star")
                continue
            end
            labelled = false
        end
        solid = shape_union(solid, poly)
        push!(pointers, RetePointer(st, q.ra, q.dec, T, :pointer, labelled))
    end

    # graduations: minor ticks give way to star markers
    for t in ticks
        major = round(Int, t.λ) % 10 == 0
        seg = Segment(t.outer, t.inner)
        if !major && any(m -> distance_to(seg, m) < mark_r + clear, markers)
            continue
        end
        push!(engrave, seg)
    end
    append!(engrave, Circle(m, mark_r) for m in markers)
    # sign names in the inner half of the band, slid along it to clear the markers
    for (k, name) in enumerate(ZODIAC)
        hs = min(0.36band, mm(style.label_height) * 1.4)
        chosen = nothing
        for off in (15, 11, 19, 8, 22, 5, 25)
            e = ecliptic_point(P, ε, 30(k - 1) + off)
            ψ = angle_of(e - E.c)
            lab =
                Label(name, E.c + polar(E.r - 0.72band, ψ), hs; angle = upright(ψ - π / 2))
            chosen === nothing && (chosen = lab)
            if !near_marker(polygon_shape(label_box(lab)))
                chosen = lab
                break
            end
        end
        push!(labels, chosen)
    end
    solid = shape_intersection(solid, rete_disk)
    # fill small enclosed gaps (slivers between pointers and the structure)
    fill_d = max(3.0, 3min_feature)
    solid = Shape([
        c for c in solid.contours if
        signed_area(c) > 0 || 2sqrt(-signed_area(c) / π) * s >= fill_d
    ])
    # notches, unless one would cut a piece off
    npieces = length(components(solid))
    for (i, nt) in enumerate(notches)
        cut = shape_difference(solid, nt)
        if length(components(cut)) == npieces
            solid = cut
        else
            j = findfirst(p -> p.kind === :notch && p.tip == notch_tips[i], pointers)
            st = pointers[j].star
            deleteat!(pointers, j)
            push!(skipped, st.name => "on the edge of the rete structure")
        end
    end
    hole = disk_shape(O, pin_radius / s; tol)
    solid = shape_difference(solid, hole)
    return Rete(
        epoch,
        P,
        ε,
        s,
        r_out,
        pin_radius / s,
        style,
        E,
        E.r - band,
        ticks,
        pointers,
        skipped,
        solid,
        engrave,
        labels,
    )
end

function Base.show(io::IO, r::Rete)
    np = count(p -> p.kind === :pointer, r.pointers)
    print(
        io,
        "Rete(",
        r.epoch,
        ", ",
        np,
        " pointers, ",
        length(r.pointers) - np,
        " markers, ",
        length(r.skipped),
        " skipped)",
    )
end
