# Verification of a complete instrument: every part against its astronomical
# definition, the instrument in use against closed-form spherical astronomy, and the
# parts against the fabrication profile.

# rete frame (local sidereal time 0): a body of right ascension α stands at H = −α
function rete_radec(P::Stereographic, p::Pt)
    h = unproject(P, p)
    return mod(-h.H, 360), h.dec
end

function ecliptic_lat_lon(α, δ, ε)
    β = asind(sind(δ) * cosd(ε) - cosd(δ) * sind(ε) * sind(α))
    λ = mod(atand(sind(α) * cosd(ε) + tand(δ) * sind(ε), cosd(α)), 360)
    return β, λ
end

angdiff(a, b; period = 360.0) = abs(mod(a - b + period / 2, period) - period / 2)

function separation(α1, δ1, α2, δ2)
    # haversine, degrees
    h = sind((δ2 - δ1) / 2)^2 + cosd(δ1) * cosd(δ2) * sind((α2 - α1) / 2)^2
    return 2asind(sqrt(min(h, 1.0)))
end

function rete_checks(a::Astrolabe; tol, n)
    r = a.rete
    P = r.projection
    ε = r.obliquity
    s = a.scale
    E = r.ecliptic
    out = CurveCheck[]
    push!(
        out,
        check_curve(
            [E],
            [ecliptic_point(P, ε, 360i / n) for i = 0:(n-1)];
            tol,
            label = "rete: ecliptic  sphere→plate",
        ),
    )
    push!(
        out,
        check_definition(
            [E],
            p -> first(ecliptic_lat_lon(rete_radec(P, p)..., ε));
            tol,
            label = "rete: ecliptic  plate→sphere",
        ),
    )
    push!(
        out,
        CurveCheck(
            "rete: ecliptic graduations (°)",
            [
                angdiff(last(ecliptic_lat_lon(rete_radec(P, t.outer)..., ε)), t.λ) for
                t in r.ticks
            ],
            tol,
        ),
    )
    seps = Float64[]
    onpart = Float64[]
    for p in r.pointers
        q = precess_to(p.star, a.epoch)
        α, δ = rete_radec(P, p.tip)
        push!(seps, separation(α, δ, q.ra, q.dec))
        if p.kind === :marker
            push!(onpart, point_in_shape(r.solid, p.tip) ? 0.0 : 1.0)
        else
            push!(onpart, nearest_boundary_point(r.solid, p.tip)[2] * s)
        end
    end
    push!(out, CurveCheck("rete: star positions (°)", seps, tol))
    push!(out, CurveCheck("rete: star tips on the cut outline (mm)", onpart, 1e-4))
    push!(out, CurveCheck("rete: one piece", [abs(length(components(r.solid)) - 1.0)], 0.0))
    return out
end

function scale_checks(a::Astrolabe; tol)
    P = a.projection
    m = a.mater
    out = CurveCheck[]
    hour_H(t) = 15 * (t - m.clock_offset - 12)
    dir_H(θ) = unproject(P, polar(1.0, θ)).H
    push!(
        out,
        CurveCheck(
            "limb: hour scale (°)",
            [angdiff(dir_H(t.angle), hour_H(t.value)) for t in m.hours.ticks],
            tol,
        ),
    )
    push!(
        out,
        CurveCheck(
            "limb: degree scale (°)",
            [angdiff(dir_H(t.angle), t.value) for t in m.degrees.ticks],
            tol,
        ),
    )
    push!(
        out,
        CurveCheck(
            "rule: declination scale (°)",
            [abs(unproject(P, seg.a).dec - δ) for (δ, seg) in a.rule.ticks],
            tol,
        ),
    )
    return out
end

function back_checks(a::Astrolabe; tol, n)
    b = a.back
    sim = simulate(a)
    ecc = b.calendar_kind === :eccentric
    out = CurveCheck[]
    push!(
        out,
        CurveCheck(
            "back: calendar → Sun's longitude (°)" * (ecc ? " (eccentric model)" : ""),
            [
                angdiff(
                    calendar_longitude(sim, (d.month, d.day)),
                    sun_position(d.jd).longitude,
                ) for d in b.calendar
            ],
            ecc ? 0.1 : 1e-6,
        ),
    )
    push!(
        out,
        CurveCheck(
            "back: equation of time (min)",
            [
                abs(eot_reading(sim, (d.month, d.day)) - equation_of_time(d.jd)) for
                d in b.calendar
            ],
            0.01,
        ),
    )
    nb = b.shadow_base
    sq = Float64[]
    for (kind, j, seg) in b.shadow_ticks
        p = seg.a
        push!(
            sq,
            kind === :versa ? abs(abs(p.y / p.x) - j / nb) : abs(abs(p.x / p.y) - j / nb),
        )
    end
    push!(out, CurveCheck("back: shadow square divisions", sq, tol))
    uh = Float64[]
    for (k, prims) in b.unequal_hours, p in prims, q in sample_points(p, 50)
        push!(uh, abs(norm2(q) - b.unequal_radius * sind(15k) * abs(sin(angle_of(q)))))
    end
    push!(out, CurveCheck("back: unequal-hour circles  sin a = sin a₀ · sin 15k", uh, tol))
    if !isempty(b.sine_quadrant)
        N = b.sine_divisions
        push!(
            out,
            CurveCheck(
                "back: sine quadrant lines",
                [
                    abs((axis === :x ? l.a.x : l.a.y) - b.sine_radius * j / N) for
                    (axis, j, l) in b.sine_quadrant
                ],
                tol,
            ),
        )
    end
    return out
end

# ---------------------------------------------------------------- the instrument in use

"Closed-form sunrise/sunset (apparent solar time, hours) for declination δ; nothing if none."
function closed_rise_set(φ, δ)
    c = -tand(φ) * tand(δ)
    abs(c) >= 1 && return nothing
    H0 = acosd(c) / 15
    return (12 - H0, 12 + H0)
end

function simulation_checks(a::Astrolabe; tol_min = 1e-3)
    out = CurveCheck[]
    ε = a.rete.obliquity
    for (ip, plate) in enumerate(a.plates)
        sim = simulate(a; plate = ip)
        φ = plate.latitude
        pre = length(a.plates) > 1 ? @sprintf("%.4g°: ", φ) : ""
        rs = Float64[]
        alt = Float64[]
        tr = Float64[]
        az = Float64[]
        a0 = 20.0
        has_alt = any(e -> e.kind === :almucantar && isapprox(e.value, a0), plate.elements)
        for m = 1:12, d in (1, 15)
            λ = calendar_longitude(sim, (m, d))
            δ = asind(sind(ε) * sind(λ))
            αs = mod(atand(sind(λ) * cosd(ε), cosd(λ)), 360)
            cf = closed_rise_set(φ, δ)
            r, st = sunrise(sim, (m, d)), sunset(sim, (m, d))
            if cf !== nothing && r !== nothing && st !== nothing
                push!(rs, 60angdiff(r.apparent, cf[1]; period = 24.0))
                push!(rs, 60angdiff(st.apparent, cf[2]; period = 24.0))
                A = acosd(clamp(sind(δ) / cosd(φ), -1, 1))
                A = φ >= 0 ? A : 180 - A
                z = sunrise_azimuth(sim, (m, d))
                z === nothing || push!(az, angdiff(z, A))
            end
            if has_alt
                c = (sind(a0) - sind(φ) * sind(δ)) / (cosd(φ) * cosd(δ))
                if abs(c) < 1 - 1e-6
                    t = time_from_altitude(sim, :Sun, a0, (m, d); side = :east)
                    t === nothing ||
                        push!(alt, 60angdiff(t.apparent, 12 - acosd(c) / 15; period = 24.0))
                end
            end
            for p in a.rete.pointers[1:min(end, 8)]
                q = precess_to(p.star, a.epoch)
                t = star_transit(sim, p.star.name, (m, d))
                t === nothing && continue
                # on the meridian the star's hour angle is 0, so the Sun's is α* − α☉
                push!(tr, 60angdiff(t.apparent, 12 + (q.ra - αs) / 15; period = 24.0))
            end
        end
        push!(out, CurveCheck(pre * "use: sunrise and sunset (min)", rs, tol_min))
        has_alt && push!(
            out,
            CurveCheck(pre * "use: time from the Sun's altitude 20° (min)", alt, tol_min),
        )
        push!(out, CurveCheck(pre * "use: star transits (min)", tr, tol_min))
        push!(
            out,
            CurveCheck(
                pre * "use: sunrise azimuth between azimuth lines (°, info)",
                az,
                Inf,
            ),
        )
    end
    return out
end

# ---------------------------------------------------------------- fabrication

function fabrication_checks(a::Astrolabe, profile::Profile; tol::Real = 2e-5)
    s = a.scale
    mm(x) = x / s
    out = CurveCheck[]
    mf = profile.min_feature
    hole_min = max(min_hole(profile), 0.0)
    for part in parts(a; tol)
        nm = part.name
        solid = part.solid
        push!(
            out,
            CurveCheck("$nm: one piece", [abs(length(components(solid)) - 1.0)], 0.0),
        )
        nl = narrowest_loss(solid, mm(mf); tol)
        push!(
            out,
            CurveCheck(
                @sprintf("%s: no bridge narrower than %.2g mm", nm, mf),
                [max(nl.after - nl.before, 0.0)],
                0.0,
            ),
        )
        hs = [2sqrt(abs(signed_area(c)) / π) * s for c in holes(solid)]
        push!(
            out,
            CurveCheck(
                @sprintf("%s: holes ≥ %.2g mm", nm, hole_min),
                [0.0; [max(hole_min - d, 0.0) for d in hs]],
                0.0,
            ),
        )
        isempty(part.labels) && continue
        push!(
            out,
            CurveCheck(
                @sprintf("%s: text ≥ %.2g mm high", nm, profile.min_text),
                [max(profile.min_text - l.height * s, 0.0) for l in part.labels],
                1e-9,
            ),
        )
        inner = shape_offset(solid, -mm(profile.engrave_margin) * 0.999; tol)
        off = Float64[]
        for l in part.labels, q in label_box(l)
            push!(
                off,
                point_in_shape(inner, q) ? 0.0 : nearest_boundary_point(inner, q)[2] * s,
            )
        end
        push!(
            out,
            CurveCheck(
                @sprintf(
                    "%s: text %.2g mm inside the edges (mm)",
                    nm,
                    profile.engrave_margin
                ),
                off,
                1e-6,
            ),
        )
        boxes = [polygon_shape(label_box(l)) for l in part.labels]
        bb = [bounds(contour_prims(b)) for b in boxes]
        ov = [0.0]                      # no pair overlaps unless found below
        for i in eachindex(boxes), j = (i+1):length(boxes)
            (
                bb[i][3] < bb[j][1] ||
                bb[j][3] < bb[i][1] ||
                bb[i][4] < bb[j][2] ||
                bb[j][4] < bb[i][2]
            ) && continue
            push!(ov, shape_area(shape_intersection(boxes[i], boxes[j])) * s^2)
        end
        push!(out, CurveCheck("$nm: no overlapping text (mm²)", ov, 1e-6))
    end
    return out
end

"""
    verify(a::Astrolabe; tol = 1e-9, n = 720, fabrication = true) -> VerificationReport

Check the whole instrument:

- every plate line against its definition on the sphere (both directions);
- the rete's ecliptic, its graduations and every star tip against the precessed
  catalogue position, and that the rete is one piece;
- the limb's hour and degree scales and the rule's declination scale;
- the back: calendar against the Sun's longitude, equation of time, shadow square,
  unequal-hour circles, sine quadrant;
- the instrument in use (see [`simulate`](@ref)): sunrise/sunset, time from altitude and
  star transits read off the drawn geometry, against closed-form spherical astronomy;
- with `fabrication = true`, the parts against `a.profile`: one piece each, no bridge
  narrower than the minimum feature, hole sizes, text height, text inside the edges,
  no overlapping text.
"""
function verify(a::Astrolabe; tol::Real = 1e-9, n::Integer = 720, fabrication::Bool = true)
    checks = CurveCheck[]
    for p in a.plates
        append!(
            checks,
            plate_checks(p; tol, n, prefix = @sprintf("plate %.4g°: ", p.latitude)),
        )
    end
    append!(checks, rete_checks(a; tol, n))
    append!(checks, scale_checks(a; tol))
    append!(checks, back_checks(a; tol, n))
    append!(checks, simulation_checks(a))
    fabrication && append!(checks, fabrication_checks(a, a.profile))
    return VerificationReport(string(a), checks)
end

# ---------------------------------------------------------------- error budget

# deterministic low-discrepancy samples in [0, 1)
function halton(i::Integer, b::Integer)
    f, r = 1.0, 0.0
    while i > 0
        f /= b
        r += f * (i % b)
        i ÷= b
    end
    return r
end

"""
    error_budget(a::Astrolabe; n = 64) -> NamedTuple

How fabrication error shows up in use. Each of `n` trials (deterministic quasi-random
samples) displaces the rete on its pin by up to the hole clearance, scales it by up to
the profile's `scale_tolerance`, and misreads the rule by half an engraved line width at
the limb; the sunrise times on the 1st and 15th of every month are read and compared
with the unperturbed instrument. Returns the `median`, `p95` and `max` error in minutes.
"""
function error_budget(a::Astrolabe; n::Integer = 64)
    fp = a.profile
    s = a.scale
    base = simulate(a)
    dates = [(m, d) for m = 1:12 for d in (1, 15)]
    ref = [sunrise(base, d) for d in dates]
    errs = Float64[]
    for i = 1:n
        ρ = (fp.hole_clearance / 2) / s * sqrt(halton(i, 2))
        θ = 2π * halton(i, 3)
        k = 1 + fp.scale_tolerance * (2halton(i, 5) - 1)
        δθ = (stroke_width(fp) / 2) / (a.mater.ring_inner * s) * (2halton(i, 7) - 1)
        sim = simulate(a; rete_offset = polar(ρ, θ), rete_scale = k, reading_offset = δθ)
        for (d, r0) in zip(dates, ref)
            r0 === nothing && continue
            r = sunrise(sim, d)
            r === nothing && continue
            push!(errs, 60angdiff(r.apparent, r0.apparent; period = 24.0))
        end
    end
    sort!(errs)
    q(p) = errs[clamp(ceil(Int, p * length(errs)), 1, length(errs))]
    return (median = q(0.5), p95 = q(0.95), max = last(errs))
end
