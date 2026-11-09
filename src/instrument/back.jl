# The back of the mater: altitude scale, zodiac and calendar rings, equation of time,
# shadow square, unequal-hours diagram and an optional sine quadrant.
#
# Back conventions (as seen from the back): the alidade turns about the centre. Altitude
# is the angle of the alidade above the horizontal diameter. Ecliptic longitude λ is
# read at back angle θ = 180° − λ (0° Aries on the left, increasing clockwise, so the
# summer signs are at the top).

"Back angle (radians) of ecliptic longitude `λ` (degrees)."
zodiac_angle(λ) = deg2rad(180 - λ)
"Ecliptic longitude (degrees) at back angle `θ` (radians)."
zodiac_longitude(θ) = mod(180 - rad2deg(θ), 360)

"Days in `month` of `year` in the given calendar."
function days_in_month(year::Integer, month::Integer; calendar::Symbol = :gregorian)
    month == 2 || return (31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31)[month]
    leap =
        calendar === :julian ? mod(year, 4) == 0 :
        (mod(year, 4) == 0 && (mod(year, 100) != 0 || mod(year, 400) == 0))
    return leap ? 29 : 28
end

const MONTHS =
    ("JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC")

"A day on the calendar ring: date, the Julian Day of its noon, and the tick."
struct CalendarDay
    month::Int
    day::Int
    jd::Float64
    angle::Float64
    outer::Pt
    inner::Pt
end

"""
    Back

The back of the mater. Scales are [`CircularScale`](@ref)s or explicit geometry, all
centred on the origin except an eccentric calendar ring.
"""
struct Back
    altitude::CircularScale
    zodiac::CircularScale
    calendar::Vector{CalendarDay}
    calendar_kind::Symbol
    calendar_center::Pt
    calendar_radius::Tuple{Float64,Float64}
    year::Int
    calendar_system::Symbol
    eot_zero::Float64
    eot_scale::Float64
    eot_curve::Polyline
    eot_grid::Vector{Primitive}
    shadow_square::Vector{Primitive}
    shadow_ticks::Vector{Tuple{Symbol,Int,Segment}}
    shadow_base::Int
    shadow_side::Float64
    unequal_hours::Vector{Tuple{Int,Vector{Primitive}}}
    unequal_radius::Float64
    sine_quadrant::Vector{Tuple{Symbol,Int,Primitive}}
    sine_divisions::Int
    sine_radius::Float64
    engrave::Vector{Primitive}
    labels::Vector{Label}
end

function Back(;
    radius,
    scale,
    epoch::Epoch,
    label_h,
    min_space,
    min_text = 0.0,
    timezone = nothing,
    calendar_kind::Symbol = :concentric,
    shadow_base::Integer = 12,
    sine_quadrant::Bool = false,
    sine_divisions::Integer = 30,
    tol = 2e-5,
)
    s = scale
    mm(x) = x / s
    O = Pt(0, 0)
    calendar_kind in (:concentric, :eccentric) ||
        throw(ArgumentError("calendar must be :concentric or :eccentric"))
    shadow_base in (7, 12) || throw(ArgumentError("shadow_base must be 7 or 12"))
    engrave = Primitive[]
    labels = Label[]
    w = radius / 75 * s            # widths below are for a 150 mm instrument, scaled
    k = w / s                      # units per "150 mm millimetre"
    r_alt = (radius - mm(0.8) - 4.2k, radius - mm(0.8))
    r_zod = (r_alt[1] - 7.0k, r_alt[1])
    r_cal = (r_zod[1] - 8.5k, r_zod[1])
    r_eot = (r_cal[1] - 8.5k, r_cal[1] - 0.6k)
    r_inner = r_eot[1] - 1.2k

    # altitude scale: two upper quadrants, 0° on the horizontal, 90° at the top
    alt_vals = Float64[]
    angles = Float64[]
    step = r_alt[1] * deg2rad(1) * s >= min_space + 0.2 ? 1 : 2
    for v = 0:step:90
        push!(alt_vals, v)
    end
    altlen(v) = (v % 10 == 0 ? 0.6 : v % 5 == 0 ? 0.42 : 0.26) * (r_alt[2] - r_alt[1])
    alt_right = radial_scale(
        :altitude,
        O,
        alt_vals,
        v -> deg2rad(v),
        r_alt...,
        tick_len = altlen,
        label_values = 10:10:80,
        label_r = r_alt[1] + 0.25(r_alt[2] - r_alt[1]),
        label_h = min(label_h, 0.33(r_alt[2] - r_alt[1])),
        rings = false,
    )
    alt_left = radial_scale(
        :altitude_left,
        O,
        alt_vals,
        v -> deg2rad(180 - v),
        r_alt...,
        tick_len = altlen,
        label_values = 10:10:80,
        label_r = r_alt[1] + 0.25(r_alt[2] - r_alt[1]),
        label_h = min(label_h, 0.33(r_alt[2] - r_alt[1])),
        rings = false,
    )
    append!(engrave, scale_prims(alt_left))
    append!(labels, alt_left.labels)
    append!(engrave, clip(Primitive[Circle(O, r_alt[1])], HalfPlane(O, Pt(0, 1))))
    push!(engrave, Segment(Pt(-r_alt[2], 0), Pt(r_alt[2], 0)))
    push!(engrave, Segment(Pt(0, -r_alt[2]), Pt(0, r_alt[2])))

    # zodiac ring
    zstep = r_zod[1] * deg2rad(1) * s >= min_space + 0.2 ? 1 : 2
    zlen(λ) =
        (λ % 30 == 0 ? 1.0 : λ % 10 == 0 ? 0.36 : λ % 5 == 0 ? 0.27 : 0.18) *
        (r_zod[2] - r_zod[1])
    zodiac = radial_scale(
        :zodiac,
        O,
        0:zstep:(360-zstep),
        zodiac_angle,
        r_zod...;
        tick_len = zlen,
    )
    for (i, name) in enumerate(ZODIAC)
        θ = zodiac_angle(30(i - 1) + 15)
        push!(
            labels,
            Label(
                name,
                polar(r_zod[1] + 0.35(r_zod[2] - r_zod[1]), θ),
                min(label_h * 1.2, 0.3(r_zod[2] - r_zod[1]));
                angle = upright(θ - π / 2),
            ),
        )
    end
    append!(engrave, scale_prims(zodiac))
    append!(engrave, scale_prims(alt_right))
    append!(labels, alt_right.labels)

    # calendar ring for the epoch's year, at noon (standard time if a time zone is given)
    year = floor(Int, epoch.year)
    cal = epoch.calendar
    tz = timezone === nothing ? 0.0 : Float64(timezone)
    days = CalendarDay[]
    ecc = calendar_kind === :eccentric
    sun0 = sun_position(calendar_to_jd(year, 1, 1.5; calendar = cal))
    # eccentric model: uniform motion on a circle whose centre is displaced towards the
    # apogee by twice the eccentricity (in longitude space, mirrored onto the back)
    T0 = julian_centuries(calendar_to_jd(year, 7, 1.5; calendar = cal))
    e_orb = 0.016708634 - T0 * (0.000042037 + 0.0000001267T0)
    ϖ = mod(280.46646 + 36000.76983T0 - (357.52911 + 35999.05029T0), 360)  # perihelion longitude of the Sun's apparent orbit
    ρc = (r_cal[1] + r_cal[2]) / 2
    C = ecc ? mirror_x(polar(2e_orb * ρc, deg2rad(ϖ + 180))) : O
    half = (r_cal[2] - r_cal[1]) / 2 - (ecc ? 2e_orb * ρc : 0.0)
    for m = 1:12, d = 1:days_in_month(year, m; calendar = cal)
        jd = calendar_to_jd(year, m, d + 0.5; calendar = cal) - tz / 24
        sp = sun_position(jd)
        θ, outer, dir = if ecc
            ψ = deg2rad(180 - (sp.mean_longitude - 0.00569))    # back angle of uniform motion
            p = C + polar(ρc + half, ψ)
            (angle_of(p), p, unit(C - p))
        else
            θ = zodiac_angle(sp.longitude)
            (θ, polar(r_cal[2], θ), Pt(-cos(θ), -sin(θ)))
        end
        L = (d == 1 ? 1.0 : d % 10 == 0 ? 0.5 : d % 5 == 0 ? 0.38 : 0.24) * 2half * 0.62
        inner = outer + L * dir
        push!(days, CalendarDay(m, d, jd, θ, outer, inner))
        push!(engrave, Segment(outer, inner))
        if d % 10 == 0 && d < 30
            push!(
                labels,
                Label(
                    string(d),
                    outer + (0.78 * 2half * 0.62) * dir,
                    min(label_h * 0.8, 0.22 * 2half);
                    angle = upright(angle_of(-dir) - π / 2),
                ),
            )
        end
    end
    for m = 1:12
        mid = days[findfirst(x -> x.month == m && x.day == 15, days)]
        ψ = angle_of(mid.outer - C)
        push!(
            labels,
            Label(
                MONTHS[m],
                C + polar(ρc - half + 0.2 * 2half, ψ),
                min(label_h * 1.1, 0.26 * 2half);
                angle = upright(ψ - π / 2),
            ),
        )
    end
    append!(engrave, Primitive[Circle(C, ρc + half), Circle(C, ρc - half)])

    # equation of time: radius = zero line + k·E along each day's direction
    r0 = (r_eot[1] + r_eot[2]) / 2
    kE = ((r_eot[2] - r_eot[1]) / 2 - mm(0.3)) / 17
    pts = Pt[]
    for dd in days
        push!(pts, polar(r0 + kE * equation_of_time(dd.jd), dd.angle))
    end
    eot = Polyline(pts, true)
    grid = Primitive[Circle(O, r0 + kE * m) for m in (-15, -10, -5, 0, 5, 10, 15)]
    push!(engrave, eot)
    append!(engrave, grid)
    # label the grid every 5, 10 or 15 minutes, as the ring's width allows
    eh = max(min(label_h * 0.7, 3.5kE), min_text)
    estep = 5kE >= eh + mm(0.4) ? 5 : 10kE >= eh + mm(0.4) ? 10 : 15
    for m = -15:estep:15
        push!(
            labels,
            Label(
                m > 0 ? "+$m" : string(m),
                polar(r0 + kE * m, deg2rad(-90)) + Pt(mm(1.2), 0),
                eh;
                halign = :left,
            ),
        )
    end

    # shadow square (lower half): sides x = ±a, bottom y = −a, base n
    n = shadow_base
    a = 0.66r_inner
    sq = Primitive[
        Segment(Pt(-a, 0), Pt(-a, -a)),
        Segment(Pt(-a, -a), Pt(a, -a)),
        Segment(Pt(a, -a), Pt(a, 0)),
        Segment(Pt(0, 0), Pt(0, -a)),
    ]
    sticks = Tuple{Symbol,Int,Segment}[]
    tl = 0.07a
    for j = 1:n
        y = -a * j / n
        x = a * j / n
        jl = j % 3 == 0 || n == 7 ? 1.6tl : tl
        push!(sticks, (:versa, j, Segment(Pt(a, y), Pt(a - jl, y))))
        push!(sticks, (:versa, j, Segment(Pt(-a, y), Pt(-a + jl, y))))
        j < n && push!(sticks, (:recta, j, Segment(Pt(x, -a), Pt(x, -a + jl))))
        j < n && push!(sticks, (:recta, j, Segment(Pt(-x, -a), Pt(-x, -a + jl))))
        if j % 3 == 0 || n == 7
            for sgn in (-1, 1)
                push!(
                    labels,
                    Label(
                        string(j),
                        Pt(sgn * (a - 2.6tl), y),
                        min(label_h * 0.8, 0.5a / n),
                    ),
                )
                j < n && push!(
                    labels,
                    Label(string(j), Pt(sgn * x, -a + 2.6tl), min(label_h * 0.8, 0.5a / n)),
                )
            end
        end
    end
    append!(engrave, sq)
    append!(engrave, [t[3] for t in sticks])
    # captions between the centre line and the numbers on the side, shortened if need be
    hU = max(min(label_h * 0.8, 0.06a), min_text)
    xu0, xu1 = mm(1.0), a - 2.6tl - hU - mm(0.5)
    for (txt, short, y) in
        (("UMBRA VERSA", "VERSA", -0.12a), ("UMBRA RECTA", "RECTA", -0.62a))
        t = text_width(txt, hU) <= xu1 - xu0 ? txt : short
        text_width(t, hU) <= xu1 - xu0 &&
            push!(labels, Label(t, Pt((xu0 + xu1) / 2, y), hU))
    end

    # unequal hours: circles through the centre, centres on the vertical axis,
    # diameter ρ sin(15k°)  (sin a = sin a_noon · sin 15k)
    ρu = r_inner
    region = sine_quadrant ? HalfPlane(O, Pt(-1, 0)) : HalfPlane(O, Pt(0, 1))
    uh = Tuple{Int,Vector{Primitive}}[]
    hu = max(label_h * 0.7, min_text)
    last_y = Inf
    for kk = 6:-1:1
        D = ρu * sind(15kk)
        prims = clip(Circle(Pt(0, D / 2), D / 2), region)
        push!(uh, (kk, prims))
        append!(engrave, prims)
        # number each circle near its top, leaving out those that would crowd
        y = D - 0.6hu
        if last_y - y >= hu + mm(0.4)
            push!(labels, Label(string(kk), Pt(-mm(1.0), y), hu; halign = :right))
            last_y = y
        end
    end
    reverse!(uh)

    # sine quadrant (upper right)
    sq_lines = Tuple{Symbol,Int,Primitive}[]
    if sine_quadrant
        ρs = r_inner
        for j = 1:(sine_divisions-1)
            c = ρs * j / sine_divisions
            h = sqrt(ρs^2 - c^2)
            push!(sq_lines, (:x, j, Segment(Pt(c, 0), Pt(c, h))))
            push!(sq_lines, (:y, j, Segment(Pt(0, c), Pt(h, c))))
        end
        append!(engrave, [l[3] for l in sq_lines])
        append!(engrave, clip(Primitive[Circle(O, ρs)], HalfPlane(O, Pt(1, 0))))
    end
    return Back(
        alt_right,
        zodiac,
        days,
        calendar_kind,
        C,
        (ρc - half, ρc + half),
        year,
        cal,
        r0,
        kE,
        eot,
        grid,
        sq,
        sticks,
        n,
        a,
        uh,
        ρu,
        sq_lines,
        sine_divisions,
        r_inner,
        engrave,
        labels,
    )
end
