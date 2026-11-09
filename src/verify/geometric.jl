# Geometric verification of plates with the sampling harness (geometry/sampling.jl).
# Every check derives its sample points from the sphere (via SOFA's hd2ae/ae2hd and
# `project`), never from the plate formulas.

"""
    verify(plate::Plate; tol = 1e-9, n = 720) -> VerificationReport

Run forward and backward sampling checks on every element of `plate`. Distances are in
plate units (equator radius R = 1); angular residuals are in degrees.
"""
function verify(plate::Plate; tol::Real = 1e-9, n::Integer = 720)
    P = plate.projection
    φ = plate.latitude
    rl = limb_radius(plate)
    within(p) = norm2(p) <= rl * (1 - 1e-12)
    outside_limb(p) = max(norm2(p) - rl, 0.0)
    checks = CurveCheck[]
    for el in plate.elements
        name = element_label(el)
        if el.kind in (:limb, :equator, :tropic)
            δ = el.value
            fwd = [project(P, 360 * k / n, δ) for k = 0:(n-1)]
            push!(checks, check_curve(el.prims, fwd; tol, label = "$name  sphere→plate"))
            push!(
                checks,
                check_definition(
                    el.prims,
                    p -> unproject(P, p).dec - δ;
                    tol,
                    label = "$name  plate→sphere",
                ),
            )
        elseif el.kind in (:horizon, :almucantar)
            a = el.value
            fwd = filter(within, [project_altaz(P, 360 * k / n, a, φ) for k = 0:(n-1)])
            push!(checks, check_curve(el.prims, fwd; tol, label = "$name  sphere→plate"))
            res = function (p)
                h = unproject(P, p)
                return abs(altaz(h.H, h.dec, φ).alt - a) + outside_limb(p)
            end
            push!(
                checks,
                check_definition(el.prims, res; tol, label = "$name  plate→sphere"),
            )
        end
    end
    title = @sprintf("Plate %.4g° (%s), ε = %.4f°", φ, P.hemisphere, plate.obliquity)
    return VerificationReport(title, checks)
end

function element_label(el::PlateElement)
    el.kind === :almucantar && return @sprintf("almucantar %g°", el.value)
    el.kind === :horizon && return "horizon"
    el.kind === :equator && return "equator"
    return @sprintf("%s δ=%+.3f°", el.kind, el.value)
end
