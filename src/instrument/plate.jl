# Latitude-specific plates (climates).
#
# Circle formulas are written for the northern projection with |φ|. By construction
# (see projection.jl) the southern plate for −φ is the left–right mirror of the
# northern plate for +φ, and every family of circles is symmetric about the meridian, so
# the same primitives serve both. Curves that are not symmetric one by one (unequal
# hours, labels) are computed with the plate's true projection. The verification harness
# always uses the true projection, so the shortcut is itself checked.

"""
    PlateElement(kind, value, prims, layer)

One plate line (or family member): `kind` is one of `:limb`, `:equator`, `:tropic`,
`:horizon`, `:almucantar`, `:twilight`, `:azimuth`, `:meridian`, `:eastwest`,
`:unequal_hour`; `value` is its defining number (declination, altitude, azimuth from
north, or hour); `prims` are clipped primitives in plate units (R = 1); `layer` is the
fabrication layer (`:cut`, `:score`, `:engrave`, `:guide`).
"""
struct PlateElement
    kind::Symbol
    value::Float64
    prims::Vector{Primitive}
    layer::Symbol
end

"""
    Plate(latitude; kwargs...)

A plate (climate) for `latitude` in degrees (south negative; a string such as
`"47°18′N"` also works).

Keywords:
- `epoch = Epoch(2026.0)`: sets the obliquity, hence the tropics and limb;
- `hemisphere`: `:north` or `:south`, by default from the sign of the latitude;
- `almucantar_step = 2`: degrees between almucantars;
- `azimuth_step = 10`: degrees between azimuth lines (`0` for none);
- `azimuth_top = 80`: azimuth lines stop at this altitude so they don't crowd the zenith;
- `twilight = (-18,)`: altitudes of twilight lines;
- `unequal_hours = :exact`: `:exact` (polylines), `:circles` (historical 3-point
  circles) or `:none`;
- `label_height = 0.035`: cap height of labels in plate units (`0` for no labels).

Latitudes beyond ±89.5° are clamped with a warning.
"""
struct Plate
    latitude::Float64
    projection::Stereographic
    epoch::Epoch
    obliquity::Float64
    almucantar_step::Float64
    azimuth_step::Float64
    azimuth_top::Float64
    twilight::Vector{Float64}
    unequal_hours::Symbol
    elements::Vector{PlateElement}
    labels::Vector{Label}
end

const MAX_LATITUDE = 89.5

function Plate(
    latitude::Real;
    epoch::Epoch = Epoch(2026.0),
    almucantar_step::Real = 2,
    azimuth_step::Real = 10,
    azimuth_top::Real = 80,
    twilight = (-18.0,),
    unequal_hours::Symbol = :exact,
    label_height::Real = 0.035,
    hemisphere::Symbol = latitude >= 0 ? :north : :south,
)
    φ = Float64(latitude)
    abs(φ) < 90 || throw(ArgumentError("latitude must be in (−90°, 90°), got $φ"))
    if abs(φ) > MAX_LATITUDE
        @warn "Latitude $(φ)° clamped to ±$(MAX_LATITUDE)°: the plate degenerates near the pole."
        φ = copysign(MAX_LATITUDE, φ)
    end
    0 < almucantar_step < 90 || throw(ArgumentError("almucantar_step must be in (0, 90)"))
    0 <= azimuth_step <= 90 || throw(ArgumentError("azimuth_step must be in [0, 90]"))
    unequal_hours in (:exact, :circles, :none) ||
        throw(ArgumentError("unequal_hours must be :exact, :circles or :none"))
    all(t -> -90 < t < 0, twilight) ||
        throw(ArgumentError("twilight altitudes must be negative"))
    P = Stereographic(hemisphere)
    ε = obliquity(epoch)
    tw = sort!(Float64.(collect(twilight)); rev = true)
    els = plate_elements(
        P,
        φ,
        ε,
        Float64(almucantar_step),
        Float64(azimuth_step),
        Float64(azimuth_top),
        tw,
        unequal_hours,
    )
    labels = label_height > 0 ? plate_labels(P, φ, ε, els, Float64(label_height)) : Label[]
    return Plate(
        φ,
        P,
        epoch,
        ε,
        Float64(almucantar_step),
        Float64(azimuth_step),
        Float64(azimuth_top),
        tw,
        unequal_hours,
        els,
        labels,
    )
end

"""
    limb_radius(P::Stereographic, ε) -> Float64

Radius of the limb: the outer tropic (Capricorn for a northern instrument, Cancer for a
southern one).
"""
limb_radius(P::Stereographic, ε::Real) = radius_of_dec(P, outer_tropic(P, ε))
limb_radius(p::Plate) = limb_radius(p.projection, p.obliquity)

outer_tropic(P::Stereographic, ε) = P.hemisphere === :north ? -ε : ε
inner_tropic(P::Stereographic, ε) = -outer_tropic(P, ε)

"""
    almucantar_primitive(φ, a; R = 1) -> Circle or Line

Unclipped projection of the almucantar of altitude `a` at latitude `φ` (degrees),
northern convention. It cuts the meridian at `y₁ = −R tan((φ − a)/2)` (north side) and
`y₂ = R cot((φ + a)/2)` (south side); when `φ + a = 0` the circle passes through the
projection pole and becomes the line `y = y₁`.
"""
function almucantar_primitive(φ::Real, a::Real; R::Real = 1.0)
    y1 = -R * tand((φ - a) / 2)
    s = sind((φ + a) / 2)
    abs(s) < 1e-12 && return Line(Pt(0.0, y1), Pt(1.0, 0.0))
    y2 = R * cosd((φ + a) / 2) / s
    return Circle(Pt(0.0, (y1 + y2) / 2), abs(y2 - y1) / 2)
end

"""
    azimuth_primitive(φ, az; R = 1) -> Circle or Line

Unclipped projection of the vertical circle through azimuth `az` (from north through
east) at latitude `φ`, northern convention. A great circle with unit normal `n` projects
to the circle with centre `(nₓ, n_y)/n_z` and radius `1/|n_z|`; for a vertical circle
`n = (cos az, −sin az sin φ, sin az cos φ)`, so the centre is
`(R cot(az)/cos φ, −R tan φ)` and the radius `R/(cos φ |sin az|)`. The meridian
(`az = 0`) is the line `x = 0`.
"""
function azimuth_primitive(φ::Real, az::Real; R::Real = 1.0)
    s = sind(az)
    abs(s) < 1e-12 && return Line(Pt(0.0, 0.0), Pt(0.0, 1.0))
    return Circle(Pt(R * cosd(az) / (s * cosd(φ)), -R * tand(φ)), R / (cosd(φ) * abs(s)))
end

"Region of the plate above the horizon (northern convention, latitude φ ≥ 0)."
function above_horizon_region(φ::Real; R::Real = 1.0)
    h = almucantar_primitive(φ, 0.0; R)
    h isa Line && return HalfPlane(h.p, Pt(0.0, 1.0))
    return Disk(h.c, h.r)
end

"Region of the plate below the horizon."
function below_horizon_region(φ::Real; R::Real = 1.0)
    h = almucantar_primitive(φ, 0.0; R)
    h isa Line && return HalfPlane(h.p, Pt(0.0, -1.0))
    return OutsideDisk(h.c, h.r)
end

"""
    unequal_hour_points(P, φ, k, ε; n = 241) -> Vector{Pt}

Exact projection of the line of the `k`-th unequal (seasonal) hour of the night: for
each declination δ between the tropics, the nocturnal arc from sunset to sunrise is
divided into twelve equal parts. Where the Sun never sets or never rises (arctic
plates) the curve stops at the polar-day boundary. The curve is parameterised by the
sunset hour angle, which keeps it smooth up to that boundary.
"""
function unequal_hour_points(
    P::Stereographic,
    φ::Real,
    k::Integer,
    ε::Real;
    n::Union{Nothing,Integer} = nothing,
    tol::Real = 5e-6,
)
    hour_point(Hs, δ) = project(P, Hs + k * (360 - 2Hs) / 12, δ)
    if abs(φ) < 1e-9                       # equator: every semi-arc is 90°
        f0(u) = hour_point(90.0, u)
        return n === nothing ? adaptive_curve(f0, -ε, ε; tol) :
               [f0(-ε + 2ε * i / (n - 1)) for i = 0:(n-1)]
    end
    # stop just short of the polar-day boundary, where all twelve hours meet
    sunset(δ) = acosd(clamp(-tand(φ) * tand(δ), -1, 1))
    u1, u2 = clamp.((sunset(-ε), sunset(ε)), POLAR_MARGIN, 180 - POLAR_MARGIN)
    f(Hs) = hour_point(Hs, atand(-cosd(Hs) / tand(φ)))   # Hs: sunset hour angle
    return n === nothing ? adaptive_curve(f, u1, u2; tol) :
           [f(u1 + (u2 - u1) * i / (n - 1)) for i = 0:(n-1)]
end

const POLAR_MARGIN = 1e-3

"""
    adaptive_curve(f, u1, u2; tol, n0 = 17, maxdepth = 16) -> Vector{Pt}

Points `f(u)` for `u ∈ [u1, u2]`, bisecting until every chord midpoint is within `tol`
of the curve.
"""
function adaptive_curve(
    f,
    u1::Real,
    u2::Real;
    tol::Real,
    n0::Integer = 17,
    maxdepth::Integer = 16,
)
    us = range(u1, u2; length = n0)
    pts = [f(us[1])]
    function refine(a, pa, b, pb, depth)
        m = (a + b) / 2
        pm = f(m)
        if depth < maxdepth && norm2(pm - (pa + pb) / 2) > tol
            refine(a, pa, m, pm, depth + 1)
            refine(m, pm, b, pb, depth + 1)
        else
            push!(pts, pm)
            push!(pts, pb)
        end
    end
    for i = 1:(n0-1)
        refine(us[i], pts[end], us[i+1], f(us[i+1]), 0)
    end
    return pts
end

"""
    unequal_hour_residual(φ, H, δ, k) -> Float64

How far (in hours of hour angle) the point `(H, δ)` is from the line of the `k`-th
unequal hour of the night: `H = Hs + k (360° − 2Hs)/12` with `Hs` the sunset hour angle.
"""
function unequal_hour_residual(φ::Real, H::Real, δ::Real, k::Integer)
    Hs = acosd(clamp(-tand(φ) * tand(δ), -1, 1))
    d = mod(H - (Hs + k * (360 - 2Hs) / 12) + 180, 360) - 180
    return d / 15
end

"Circle through three points (`nothing` if they are collinear)."
function circle_through(a::Pt, b::Pt, c::Pt)
    d = 2 * (a.x * (b.y - c.y) + b.x * (c.y - a.y) + c.x * (a.y - b.y))
    abs(d) < 1e-14 && return nothing
    a2, b2, c2 = dot2(a, a), dot2(b, b), dot2(c, c)
    ux = (a2 * (b.y - c.y) + b2 * (c.y - a.y) + c2 * (a.y - b.y)) / d
    uy = (a2 * (c.x - b.x) + b2 * (a.x - c.x) + c2 * (b.x - a.x)) / d
    ctr = Pt(ux, uy)
    return Circle(ctr, norm2(a - ctr))
end

function plate_elements(P, φ, ε, step, az_step, az_top, twilight, uh)
    φn = abs(φ)                     # see the note at the top of this file
    R = P.R
    rl = limb_radius(P, ε)
    D = Circle(Pt(0, 0), rl)
    LIMB = Disk(Pt(0, 0), rl)
    els = PlateElement[]
    dec_circle(δ) = Circle(Pt(0, 0), radius_of_dec(P, δ))
    push!(
        els,
        PlateElement(:limb, outer_tropic(P, ε), [dec_circle(outer_tropic(P, ε))], :cut),
    )
    push!(els, PlateElement(:equator, 0.0, [dec_circle(0.0)], :engrave))
    push!(
        els,
        PlateElement(
            :tropic,
            inner_tropic(P, ε),
            [dec_circle(inner_tropic(P, ε))],
            :engrave,
        ),
    )
    push!(els, PlateElement(:meridian, 0.0, clip(Line(Pt(0, 0), Pt(0, 1)), LIMB), :engrave))
    push!(
        els,
        PlateElement(:eastwest, 90.0, clip(Line(Pt(0, 0), Pt(1, 0)), LIMB), :engrave),
    )
    push!(
        els,
        PlateElement(
            :horizon,
            0.0,
            clip_to_disk(almucantar_primitive(φn, 0.0; R), D),
            :engrave,
        ),
    )
    a = step
    while a < 90 - 1e-9
        prims = clip_to_disk(almucantar_primitive(φn, a; R), D)
        isempty(prims) || push!(els, PlateElement(:almucantar, a, prims, :engrave))
        a += step
    end
    for t in twilight
        prims = clip_to_disk(almucantar_primitive(φn, t; R), D)
        isempty(prims) || push!(els, PlateElement(:twilight, t, prims, :engrave))
    end
    if az_step > 0
        above = above_horizon_region(φn; R)
        cap = almucantar_primitive(φn, az_top; R)::Circle
        az = az_step
        while az < 180 - 1e-9
            prims = clip(azimuth_primitive(φn, az; R), LIMB)
            prims = clip(clip(prims, above), OutsideDisk(cap.c, cap.r))
            isempty(prims) || push!(els, PlateElement(:azimuth, az, prims, :engrave))
            az += az_step
        end
    end
    if uh !== :none
        below = below_horizon_region(φn; R)
        for k = 1:11
            pts = unequal_hour_points(P, φ, k, ε)
            length(pts) >= 2 || continue
            prims = if uh === :exact
                Primitive[Polyline(pts)]
            else
                c = circle_through(pts[1], pts[(length(pts)+1)÷2], pts[end])
                c === nothing ? Primitive[Segment(pts[1], pts[end])] :
                clip(
                    clip(
                        clip(c, LIMB),
                        OutsideDisk(Pt(0, 0), radius_of_dec(P, inner_tropic(P, ε)) - 1e-12),
                    ),
                    below,
                )
            end
            isempty(prims) || push!(els, PlateElement(:unequal_hour, k, prims, :engrave))
        end
    end
    return els
end

# Labels: almucantar altitudes along the meridian, azimuths just above the horizon,
# unequal-hour numbers on the equator, and the latitude near the bottom of the plate.
function plate_labels(P, φ, ε, els, h)
    labels = Label[]
    rl = limb_radius(P, ε)
    φn = abs(φ)
    for el in els
        if el.kind === :almucantar && isapprox(mod(el.value, 10), 0; atol = 1e-9)
            y = cotd((φn + el.value) / 2)          # south crossing of the meridian
            y + h < rl * 0.98 || continue
            push!(
                labels,
                Label(
                    string(round(Int, el.value)),
                    Pt(h * 0.3, y),
                    h * 0.8;
                    halign = :left,
                    valign = :bottom,
                ),
            )
        elseif el.kind === :azimuth && isapprox(mod(el.value, 30), 0; atol = 1e-9)
            for az in (el.value, el.value + 180)
                hz = hadec(az, 3.0, φ)                # a little above the horizon
                p = project(P, hz.H, hz.dec)
                norm2(p) < rl - 2h || continue
                push!(labels, Label(string(round(Int, az)), p, h * 0.7))
            end
        end
    end
    if any(e -> e.kind === :unequal_hour, els)
        # hour numbers 1–12, centred in each unequal hour, between equator and limb
        δ = outer_tropic(P, ε) / 2
        c = -tand(φ) * tand(δ)
        if abs(c) < 1
            Hs = acosd(c)
            for k = 1:12
                p = project(P, Hs + (k - 0.5) * (360 - 2Hs) / 12, δ)
                push!(labels, Label(string(k), p, h * 0.8))
            end
        end
    end
    push!(labels, latitude_label(φ, rl, h))
    return labels
end

function latitude_label(φ, rl, h)
    m = round(Int, 60 * abs(φ))
    lat = @sprintf("%d°%02d'%s", m ÷ 60, m % 60, φ >= 0 ? "N" : "S")
    θ = deg2rad(-90 - 32)
    return Label(lat, polar(rl - 1.4h, θ), h; angle = θ + π / 2)
end

function Base.show(io::IO, p::Plate)
    print(
        io,
        "Plate(",
        p.latitude,
        "°, :",
        p.projection.hemisphere,
        ", ",
        length(p.elements),
        " elements, ε = ",
        round(p.obliquity; digits = 4),
        "°)",
    )
end
