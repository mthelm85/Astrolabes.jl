# Balance: how the instrument hangs from its shackle. The altitude scale on the back is only
# right if its horizontal diameter hangs level, which needs the centre of mass of the
# whole assembly directly below the point it hangs from. Masses are taken in proportion
# to each part's area (every part cut from the same sheet); paper, pin and shackle are
# left out.

const SIGN_NAMES = (
    "Aries",
    "Taurus",
    "Gemini",
    "Cancer",
    "Leo",
    "Virgo",
    "Libra",
    "Scorpio",
    "Sagittarius",
    "Capricorn",
    "Aquarius",
    "Pisces",
)

"Area and centroid of a shape (holes count negatively)."
function area_centroid(sh::Shape)
    A = 0.0
    cx = 0.0
    cy = 0.0
    for c in sh.contours
        n = length(c)
        for i = 1:n
            p, q = c[i], c[mod1(i + 1, n)]
            k = cross2(p, q)
            A += k / 2
            cx += (p.x + q.x) * k / 6
            cy += (p.y + q.y) * k / 6
        end
    end
    return A, Pt(cx / A, cy / A)
end

# the moving parts' centroids and the fixed parts' first moment, front frame (as seen
# from the front; back-face parts are mirrored)
struct MassModel
    total::Float64
    fixed::Pt                      # Σ A·c of the parts that do not turn
    rete::Tuple{Float64,Pt}
    rule::Tuple{Float64,Pt}
    alidade::Tuple{Float64,Pt}     # alidade with its vanes, alidade frame (back)
    pivot::Pt
end

mirror_pt(p::Pt) = Pt(-p.x, p.y)

function mass_model(a::Astrolabe)
    ps = parts(a; engraving = false)
    total = 0.0
    fixed = Pt(0, 0)
    rete = rule = alidade = (0.0, Pt(0, 0))
    vane = nothing
    mater = only(p for p in ps if p.name == "mater")
    for p in ps
        A, c = area_centroid(p.solid)
        # the one-piece mater's rim around the pocket is as deep as the pocket; the artwork
        # for a built-in plate (the recess floor) adds no mass of its own
        q =
            isempty(p.artwork_for) ? p.quantity :
            p.name == "mater_front" ? mater.pocket_depth / a.profile.thickness : 0.0
        if p.name == "rete"
            rete = (A, c)
        elseif p.name == "rule"
            rule = (A, c)
        elseif p.name == "alidade"
            alidade = (A, c)
        elseif p.name == "vane"
            vane = (A, c)
        else
            fixed += q * A * (p.face === :back ? mirror_pt(c) : c)
        end
        total += q * A
    end
    # vanes stand on the alidade: their mass sits over the mount, offset across the bar
    if vane !== nothing
        Aa, ca = alidade
        m = Aa * ca
        for (o, θ) in a.alidade.vane_mounts
            m += vane[1] * (o + rotate(Pt(vane[2].x, 0.0), θ))
        end
        Aa += vane[1] * length(a.alidade.vane_mounts)
        alidade = (Aa, m / Aa)
    end
    top = argmax(c -> maximum(q -> q.y, c), holes(mater.solid))
    pivot = Pt(0.0, maximum(q -> q.y, top))
    return MassModel(total, fixed, rete, rule, alidade, pivot)
end

"""
    hanging_tilt(a::Astrolabe; rete = 0, rule = 0, alidade = 0) -> degrees

The angle by which the instrument, hung from its shackle, hangs off true when the rete,
rule and alidade are turned by the given angles (degrees, counter-clockwise as seen from
their own face, from their drawn positions). The horizontal diameter of the altitude scale
is off level by this much, and every altitude read with the alidade is off by it.
Positive means the instrument hangs turned clockwise as seen from the front.
"""
function hanging_tilt(a::Astrolabe; rete::Real = 0, rule::Real = 0, alidade::Real = 0)
    return hanging_tilt(mass_model(a), deg2rad(rete), deg2rad(rule), deg2rad(alidade))
end

function hanging_tilt(m::MassModel, θr::Real, θu::Real, θa::Real)
    g = m.fixed
    g += m.rete[1] * rotate(m.rete[2], θr)
    g += m.rule[1] * rotate(m.rule[2], θu)
    g += m.alidade[1] * mirror_pt(rotate(m.alidade[2], θa))
    g = g / m.total
    return rad2deg(atan(g.x, m.pivot.y - g.y))
end

"""
    balanced_rete_angle(a::Astrolabe) -> degrees

Turn of the rete (degrees, as for [`hanging_tilt`](@ref)) that puts its own centre of
mass straight below the pin, where it does not tilt the hanging instrument. A rete free
to swing settles here by itself.
"""
function balanced_rete_angle(a::Astrolabe)
    c = mass_model(a).rete[2]
    return mod(rad2deg(-π / 2 - angle_of(c)), 360)
end

"""
    balanced_rete_longitude(a::Astrolabe) -> degrees

Ecliptic longitude that lies at the bottom of the rete's ecliptic ring when the rete is
turned to [`balanced_rete_angle`](@ref): "turn the rete until this point is straight
down" is how to set it by hand.
"""
function balanced_rete_longitude(a::Astrolabe)
    sim = simulate(a)
    θ = deg2rad(balanced_rete_angle(a))
    λs = 0:0.5:359.5
    ys = [rotate(ecliptic_position(sim, l), θ).y for l in λs]
    return Float64(λs[argmin(ys)])
end

function balance_checks(a::Astrolabe)
    out = CurveCheck[]
    m = mass_model(a)
    θb = deg2rad(balanced_rete_angle(a))
    sight = deg2rad.(0:5:90)
    turns = range(0, 2π; length = 37)[1:36]
    # with the rete parked balanced, nothing else that turns may tilt it: the rule and the
    # alidade (with its vanes) balance on the pin
    parked = [
        hanging_tilt(m, θb, θu, h - π / 2) - hanging_tilt(m, θb, 0.0, -π / 2) for
        θu in turns, h in sight
    ]
    push!(
        out,
        CurveCheck("balance: rule and alidade turn without tilting it (°)", vec(parked), 1e-4),
    )
    # the fixed parts and the parked rete hang it level
    push!(
        out,
        CurveCheck("balance: rete parked, hangs level (°)", [hanging_tilt(m, θb, 0.0, 0.0)], 0.02),
    )
    # the vanes stand in a blank ring: no engraving within it
    b = a.back
    if b.vane_band > 0
        lo, hi = b.vane_radius - b.vane_band / 2, b.vane_radius + b.vane_band / 2
        intrude = Float64[]
        # diameters (the altitude scale's axes, the shadow square's centre line) cross the
        # ring radially and are never read there; everything else must stay out of it
        diameter(q) = q isa Segment && abs(cross2(q.a, q.b)) < 1e-12
        for q in b.engrave, p in (diameter(q) ? Pt[] : sample_points(q, 400))
            r = norm2(p)
            push!(intrude, lo < r < hi ? min(r - lo, hi - r) * a.scale : 0.0)
        end
        for l in b.labels, p in label_box(l)
            r = norm2(p)
            push!(intrude, lo < r < hi ? min(r - lo, hi - r) * a.scale : 0.0)
        end
        push!(out, CurveCheck("back: vane ring left blank (mm)", intrude, 1e-9))
        # the vane stands in its ring and its pinhole is on the fiducial line
        al = a.alidade
        t = a.profile.thickness / a.scale
        fit = [
            max(abs(norm2(o)) + t / 2 - hi, lo - (abs(norm2(o)) - t / 2), 0.0) * a.scale for
            (o, _) in al.vane_mounts
        ]
        push!(out, CurveCheck("alidade: vanes inside the blank ring (mm)", fit, 1e-9))
        # beside the edge, on the side where scales are read, the alidade may reach only
        # into the blank ring (its vane pads) and the hub
        pads = Float64[]
        for c in al.solid.contours, p in c
            r = norm2(p)
            r > 0.3b.vane_radius || continue
            reading_side = (p.y > 0 && p.x < -1e-9) || (p.y < 0 && p.x > 1e-9)
            push!(pads, reading_side ? max(lo - r, r - hi, 0.0) * a.scale : 0.0)
        end
        push!(out, CurveCheck("alidade: crosses its edge only in the blank ring (mm)", pads, 1e-6))
        push!(
            out,
            CurveCheck(
                "alidade: pinholes on the fiducial line (mm)",
                [abs((o + rotate(Pt(al.vane_holes[1].x, 0.0), θ)).x) * a.scale for (o, θ) in al.vane_mounts],
                1e-9,
            ),
        )
    end
    return out
end
