# Geometric verification of plates with the sampling harness (geometry/sampling.jl).
# Sample points come from the sphere (via SOFA's hd2ae/ae2hd and `project`), never from
# the plate formulas; backward checks un-project the drawing and test the definition.

"Unit vector of hour angle `H`, declination `δ` (x west, y upper meridian, z north pole)."
sky_vec(H, δ) = (cosd(δ) * sind(H), cosd(δ) * cosd(H), sind(δ))

"Unit vector (east, north, up) of azimuth `az`, altitude `alt`."
horizon_vec(az, alt) = (cosd(alt) * sind(az), cosd(alt) * cosd(az), sind(alt))

dot3(a, b) = a[1] * b[1] + a[2] * b[2] + a[3] * b[3]

"""
    verify(plate::Plate; tol = 1e-9, n = 720) -> VerificationReport

Forward (sphere → plate) and backward (plate → sphere) sampling checks on every element
of `plate`. Distances are in plate units (R = 1); angular residuals in degrees; unequal
hours in hours.
"""
function verify(plate::Plate; tol::Real = 1e-9, n::Integer = 720)
    title = @sprintf(
        "Plate %.4g° (%s), ε = %.4f°",
        plate.latitude,
        plate.projection.hemisphere,
        plate.obliquity
    )
    return VerificationReport(title, plate_checks(plate; tol, n))
end

function plate_checks(plate::Plate; tol::Real = 1e-9, n::Integer = 720, prefix = "")
    P = plate.projection
    φ = plate.latitude
    rl = limb_radius(plate)
    within(p) = norm2(p) <= rl * (1 - 1e-12)
    outside_limb(p) = max(norm2(p) - rl, 0.0)
    altaz_of(p) = (h = unproject(P, p); altaz(h.H, h.dec, φ))
    checks = CurveCheck[]
    fwd!(el, name, pts) =
        push!(checks, check_curve(el.prims, pts; tol, label = "$prefix$name  sphere→plate"))
    bwd!(el, name, f; t = tol) = push!(
        checks,
        check_definition(el.prims, f; tol = t, label = "$prefix$name  plate→sphere"),
    )
    for el in plate.elements
        name = element_label(el)
        k = el.kind
        if k in (:limb, :equator, :tropic)
            δ = el.value
            fwd!(el, name, [project(P, 360 * i / n, δ) for i = 0:(n-1)])
            bwd!(el, name, p -> unproject(P, p).dec - δ)
        elseif k in (:horizon, :almucantar, :twilight)
            a = el.value
            fwd!(
                el,
                name,
                filter(within, [project_altaz(P, 360 * i / n, a, φ) for i = 0:(n-1)]),
            )
            bwd!(el, name, p -> abs(altaz_of(p).alt - a) + outside_limb(p))
        elseif k in (:meridian, :eastwest)
            Hs = k === :meridian ? (0.0, 180.0) : (90.0, -90.0)
            normal = k === :meridian ? (1.0, 0.0, 0.0) : (0.0, 1.0, 0.0)
            pts = [project(P, H, δ) for H in Hs for δ in range(-89.9, 89.9; length = n ÷ 2)]
            fwd!(el, name, filter(within, pts))
            bwd!(
                el,
                name,
                p -> begin
                    h = unproject(P, p)
                    asind(abs(dot3(sky_vec(h.H, h.dec), normal))) + outside_limb(p)
                end,
            )
        elseif k === :azimuth
            az0 = el.value
            top = plate.azimuth_top
            pts = [
                project_altaz(P, az, alt, φ) for az in (az0, az0 + 180) for
                alt in range(0, top; length = n ÷ 2)
            ]
            fwd!(el, name, filter(within, pts))
            normal = (cosd(az0), -sind(az0), 0.0)
            bwd!(
                el,
                name,
                p -> begin
                    q = altaz_of(p)
                    asind(abs(dot3(horizon_vec(q.az, q.alt), normal))) +
                    max(-q.alt, 0.0) +
                    max(q.alt - top, 0.0) +
                    outside_limb(p)
                end,
            )
        elseif k === :unequal_hour
            append!(checks, unequal_hour_checks(plate, el, name; tol, prefix))
        end
    end
    lab = [norm2(q) for l in plate.labels for q in label_box(l)]
    push!(
        checks,
        CurveCheck("$(prefix)labels inside the limb", [max(r - rl, 0.0) for r in lab], tol),
    )
    return checks
end

function unequal_hour_checks(plate::Plate, el::PlateElement, name; tol, prefix)
    P = plate.projection
    φ = plate.latitude
    ε = plate.obliquity
    hour = round(Int, el.value)
    out = CurveCheck[]
    # the exact curve, sampled more finely than it was drawn
    exact = unequal_hour_points(P, φ, hour, ε; n = 2001)
    # its definition: H = Hs + k(360° − 2Hs)/12, residual in hours
    resid(p) = (h = unproject(P, p); unequal_hour_residual(φ, h.H, h.dec, hour))
    if plate.unequal_hours === :exact
        pl = only(el.prims)::Polyline
        push!(
            out,
            CurveCheck(
                "$prefix$name  vertices plate→sphere",
                [abs(resid(p)) for p in pl.pts],
                tol,
            ),
        )
        push!(
            out,
            check_curve(el.prims, exact; tol = 1e-5, label = "$prefix$name  chord error"),
        )
    else
        push!(
            out,
            CurveCheck(
                "$prefix$name  circle approximation (info)",
                [distance_to(el.prims, p) for p in exact],
                Inf,
            ),
        )
    end
    return out
end

function element_label(el::PlateElement)
    el.kind === :almucantar && return @sprintf("almucantar %g°", el.value)
    el.kind === :twilight && return @sprintf("twilight %g°", el.value)
    el.kind === :azimuth && return @sprintf("azimuth %g°", el.value)
    el.kind === :unequal_hour && return @sprintf("unequal hour %d", el.value)
    el.kind in (:horizon, :equator, :meridian, :eastwest) && return string(el.kind)
    return @sprintf("%s δ=%+.3f°", el.kind, el.value)
end
