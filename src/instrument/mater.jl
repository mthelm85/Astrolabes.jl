# The mater's limb: hour and degree scales around the plates.

"""
    Mater

The body of the instrument. `radius` is the outer radius, `ring_inner` the inner edge of
the limb ring in which the plates sit, `plate_radius` the plates' radius. `hours` and
`degrees` are the limb scales; `clock_offset` (hours) shifts the hour scale from local
apparent time to standard (zone) time before the equation of time.
"""
struct Mater
    radius::Float64
    ring_inner::Float64
    plate_radius::Float64
    throne_top::Pt
    outline::Shape
    hours::CircularScale
    degrees::CircularScale
    clock_offset::Float64
    hour_period::Float64
end

"Plate angle (radians) of hour angle `H` (degrees) on the equator."
hour_angle_direction(P::Stereographic, H::Real) = angle_of(project(P, H, 0.0))

function Mater(
    P::Stereographic;
    radius,
    ring_inner,
    plate_radius,
    scale,
    label_h,
    min_space,
    clock_offset = 0.0,
    hours::Symbol = :h24,
    tol = 2e-5,
)
    s = scale
    mm(x) = x / s
    hours in (:h24, :h12) || throw(ArgumentError("hours must be :h24 or :h12"))
    tw, th = 0.36radius, 0.17radius
    outline, top = mater_outline(radius, tw, th, mm(2.2); tol)
    band = radius - ring_inner
    r_deg_out = radius - mm(0.8)
    r_deg_in = r_deg_out - 0.33band
    r_hr_out = r_deg_in
    r_hr_in = ring_inner + mm(0.6)
    # clock value t (hours) sits where the Sun's hour angle is 15 (t − offset − 12)
    θh(t) = hour_angle_direction(P, 15 * (t - clock_offset - 12))
    pitch(step_min) = r_hr_in * deg2rad(step_min / 4) * s
    step = pitch(5) >= min_space + 0.2 ? 5 : pitch(10) >= min_space + 0.2 ? 10 : 15
    vals = [m / 60 for m = 0:step:(24*60-step)]
    len(t) =
        (m = round(Int, t * 60);
        m % 60 == 0 ? 0.55 : m % 30 == 0 ? 0.4 : m % 15 == 0 ? 0.3 : 0.2) *
        (r_hr_out - r_hr_in)
    htext(t) = (h = mod(round(Int, t), 24);
    hours === :h24 ? string(h == 0 ? 24 : h) : string(mod1(h, 12)))
    hour_scale = radial_scale(
        :hours,
        Pt(0, 0),
        vals,
        θh,
        r_hr_in,
        r_hr_out;
        tick_len = len,
        label_values = 0:23,
        label_r = r_hr_in + 0.75(r_hr_out - r_hr_in),
        label_h = min(label_h * 1.2, 0.3(r_hr_out - r_hr_in)),
        label_text = htext,
    )
    # degrees of hour angle, 0 on the upper meridian
    θd(v) = hour_angle_direction(P, v)
    dstep = r_deg_in * deg2rad(1) * s >= min_space + 0.2 ? 1 : 2
    dlen(v) = (v % 10 == 0 ? 0.5 : v % 5 == 0 ? 0.35 : 0.22) * (r_deg_out - r_deg_in)
    deg_scale = radial_scale(
        :degrees,
        Pt(0, 0),
        0:dstep:(360-dstep),
        θd,
        r_deg_in,
        r_deg_out;
        tick_len = dlen,
        label_values = 0:30:330,
        label_r = r_deg_in + 0.25(r_deg_out - r_deg_in),
        label_h = min(label_h, 0.4(r_deg_out - r_deg_in)),
    )
    return Mater(
        radius,
        ring_inner,
        plate_radius,
        top,
        outline,
        hour_scale,
        deg_scale,
        clock_offset,
        24.0,
    )
end

"Plate key: a notch at the top of each plate and a matching tab on the limb ring."
function key_shapes(
    ring_inner,
    plate_radius,
    s;
    width_mm = 4.0,
    depth_mm = 1.6,
    clearance_mm = 0.15,
)
    mm(x) = x / s
    w, d, c = mm(width_mm), mm(depth_mm), mm(clearance_mm)
    notch = rect_shape(-w / 2, plate_radius - d, w / 2, plate_radius + mm(1))
    tab = rect_shape(-w / 2 + c, plate_radius - d + c, w / 2 - c, ring_inner + mm(0.5))
    return notch, tab
end
