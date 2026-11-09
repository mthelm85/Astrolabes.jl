# The assembled instrument.

"""
    Location(longitude, timezone; name = "")

Observer longitude (degrees, east positive) and standard time zone (hours, east
positive). Used only for the time and calendar scales.
"""
struct Location
    longitude::Float64
    timezone::Float64
    name::String
end
Location(longitude::Real, timezone::Real; name::AbstractString = "") =
    Location(longitude, timezone, name)

"""
    Astrolabe

A complete planispheric astrolabe: `plates`, `rete`, `mater` (limb), `back`, `rule` and
`alidade`. Geometry is in plate units (equator radius R = 1); `scale` converts to
millimetres. Build one with [`astrolabe`](@ref).
"""
struct Astrolabe
    diameter_mm::Float64
    scale::Float64
    epoch::Epoch
    projection::Stereographic
    profile::Profile
    plates::Vector{Plate}
    rete::Rete
    mater::Mater
    back::Back
    rule::Rule
    alidade::Alidade
    location::Union{Nothing,Location}
    pin_radius::Float64
    label_mm::Float64
end

"""
    astrolabe(latitude; kwargs...) -> Astrolabe

Build an astrolabe for `latitude` (degrees, south negative, or a string like
`"51°45′N"`).

Keywords:
- `epoch = 2026.0`: a Julian year or an [`Epoch`](@ref). Years before 1582.8 use the
  Julian calendar on the back unless `calendar_system` says otherwise;
- `diameter_mm = 150`: diameter of the mater (without the throne);
- `profile = LaserCut()`: fabrication profile, see [`LaserCut`](@ref), [`Metal`](@ref),
  [`PCB`](@ref), [`Paper`](@ref);
- `latitudes = ()`: extra plates (same hemisphere);
- `longitude`, `timezone`: optional corrections for the hour scale and calendar;
- `stars = :default`: `:default`, `:all`, a list of names, or a `Vector{Star}`;
- `names = :iau`: star labels, `:iau` or `:traditional`;
- `almucantar_step = 2`, `azimuth_step = 10`, `twilight = (-18,)`,
  `unequal_hours = :exact`: plate options (see [`Plate`](@ref));
- `calendar = :concentric` or `:eccentric`; `shadow_base = 12` or `7`;
  `sine_quadrant = false`; `hours = :h24` or `:h12`;
- `rete_style`: a [`ReteStyle`](@ref) (defaults adapt to the profile).
"""
function astrolabe(
    latitude;
    epoch = 2026.0,
    diameter_mm::Real = 150,
    profile::Profile = LaserCut(),
    latitudes = (),
    longitude = nothing,
    timezone = nothing,
    stars = :default,
    names::Symbol = :iau,
    almucantar_step::Real = 2,
    azimuth_step::Real = 10,
    twilight = (-18.0,),
    unequal_hours::Symbol = :exact,
    calendar::Symbol = :concentric,
    calendar_system = nothing,
    shadow_base::Integer = 12,
    sine_quadrant::Bool = false,
    hours::Symbol = :h24,
    rete_style::Union{Nothing,ReteStyle} = nothing,
    tol::Real = 2e-5,
)
    φ = latitude isa AbstractString ? parse_latitude(latitude) : Float64(latitude)
    ep = if epoch isa Epoch
        calendar_system === nothing ? epoch : Epoch(epoch.year, calendar_system)
    else
        Epoch(
            epoch,
            calendar_system === nothing ? (epoch < 1582.8 ? :julian : :gregorian) :
            calendar_system,
        )
    end
    hemisphere = φ >= 0 ? :north : :south
    P = Stereographic(hemisphere)
    ε = obliquity(ep)
    fp = profile
    D = Float64(diameter_mm)
    D >= 60 || throw(ArgumentError("diameter_mm must be at least 60"))
    (longitude === nothing) == (timezone === nothing) ||
        throw(ArgumentError("give both longitude and timezone, or neither"))
    loc = longitude === nothing ? nothing : Location(longitude, timezone)

    # sizes: the limb ring takes 8.5 % of the diameter; plates fill the rest
    r_m_mm = D / 2
    ring_in_mm = r_m_mm - 0.085D
    plate_mm = ring_in_mm - fp.fit_clearance / 2
    s = plate_mm / limb_radius(P, ε)              # mm per plate unit
    mm(x) = x / s
    label_mm = max(fp.min_text, 0.011D)
    pin_r = mm((fp.pin_diameter + fp.hole_clearance) / 2)

    lats = [φ; Float64[l isa AbstractString ? parse_latitude(l) : l for l in latitudes]]
    all(l -> (l >= 0) == (φ >= 0), lats) ||
        throw(ArgumentError("all plates must be in the same hemisphere"))
    plates = [
        Plate(
            l;
            epoch = ep,
            almucantar_step,
            azimuth_step,
            twilight,
            unequal_hours,
            label_height = mm(label_mm),
            hemisphere,
        ) for l in lats
    ]

    starlist = stars isa AbstractVector{Star} ? stars : catalog_stars(stars)
    mf = fp.min_feature
    style =
        rete_style === nothing ?
        ReteStyle(;
            rim_width = max(3.0, 2.5mf),
            ecliptic_width = max(7.0, 6mf),
            tropic_width = max(2.2, 2mf),
            bar_width = max(2.6, 2.2mf),
            hub_radius = max(6.5, fp.pin_diameter + 3mf),
            pointer_width = max(2.8, 2mf, label_mm * 1.7),
            label_height = label_mm,
            names,
        ) : rete_style
    rete = Rete(
        ep,
        P;
        stars = starlist,
        scale = s,
        style,
        pin_radius = fp.pin_diameter / 2 + fp.hole_clearance / 2,
        clearance = fp.fit_clearance,
        min_feature = mf,
        tol,
    )

    offset = loc === nothing ? 0.0 : (loc.timezone * 15 - loc.longitude) / 15
    mater = Mater(
        P;
        radius = mm(r_m_mm),
        ring_inner = mm(ring_in_mm),
        plate_radius = mm(plate_mm),
        scale = s,
        label_h = mm(label_mm),
        min_space = fp.min_space,
        clock_offset = offset,
        hours,
        tol,
    )
    back = Back(;
        radius = mm(r_m_mm),
        scale = s,
        epoch = ep,
        label_h = mm(label_mm),
        min_space = fp.min_space,
        min_text = mm(fp.min_text),
        timezone = loc === nothing ? nothing : loc.timezone,
        calendar_kind = calendar,
        shadow_base,
        sine_quadrant,
        tol,
    )
    rule = Rule(
        P,
        ε;
        half_length = mm(r_m_mm - 1.0),
        scale = s,
        pin_radius = pin_r,
        width_mm = max(
            10.0,
            5mf,
            2(text_width("-20", fp.min_text) + fp.engrave_margin + 0.8),
        ),
        label_h = mm(label_mm),
        min_space = fp.min_space,
        tol,
    )
    alidade = Alidade(;
        half_length = mm(r_m_mm - 0.5),
        scale = s,
        pin_radius = pin_r,
        thickness_mm = fp.thickness,
        width_mm = max(
            10.0,
            5mf,
            2(text_width("-20", fp.min_text) + fp.engrave_margin + 0.8),
        ),
        tol,
    )
    return Astrolabe(
        D,
        s,
        ep,
        P,
        fp,
        plates,
        rete,
        mater,
        back,
        rule,
        alidade,
        loc,
        pin_r,
        label_mm,
    )
end

function Base.show(io::IO, a::Astrolabe)
    lat = join((@sprintf("%.4g°", p.latitude) for p in a.plates), ", ")
    print(
        io,
        "Astrolabe(",
        lat,
        ", ",
        a.epoch,
        ", ",
        a.diameter_mm,
        " mm, ",
        profile_name(a.profile),
        ")",
    )
end

"""
    parts(a::Astrolabe) -> Vector{Part}

The pieces to fabricate: the mater (back engraving), the limb ring, each plate, the
rete, the rule, the alidade and its two vanes.
"""
function parts(a::Astrolabe; tol::Real = 2e-5)
    s = a.scale
    mm(x) = x / s
    O = Pt(0, 0)
    m = a.mater
    pin = disk_shape(O, a.pin_radius; tol)
    notch, tab = key_shapes(m.ring_inner, m.plate_radius, s)
    margin = mm(a.profile.engrave_margin)
    fit(prims, solid) = fit_engraving(prims, solid, margin; step = mm(0.05), tol)
    txt(labels) = at_least(labels, mm(a.profile.min_text))
    out = Part[]
    # mater: the base disk, engraved on its back
    msolid = shape_difference(m.outline, pin)
    push!(
        out,
        Part(
            "mater",
            msolid,
            fit(a.back.engrave, msolid),
            Primitive[],
            txt(a.back.labels);
            face = :back,
        ),
    )
    # limb ring with its hour and degree scales and the plate key tab
    ring = shape_union(shape_difference(m.outline, disk_shape(O, m.ring_inner; tol)), tab)
    push!(
        out,
        Part(
            "limb",
            ring,
            fit([scale_prims(m.hours); scale_prims(m.degrees)], ring),
            Primitive[],
            txt([m.hours.labels; m.degrees.labels]),
        ),
    )
    # with several plates, plain spacer rings raise the limb to the height of the stack
    length(a.plates) > 1 && push!(
        out,
        Part(
            "limb_spacer",
            ring,
            Primitive[],
            Primitive[],
            Label[];
            quantity = length(a.plates) - 1,
        ),
    )
    # plates
    for p in a.plates
        solid = shape_difference(
            shape_difference(disk_shape(O, m.plate_radius; tol), notch),
            pin,
        )
        eng = reduce(
            vcat,
            [el.prims for el in p.elements if el.layer === :engrave];
            init = Primitive[],
        )
        name =
            "plate_" *
            replace(@sprintf("%.4g", abs(p.latitude)), "." => "p") *
            (p.latitude >= 0 ? "N" : "S")
        push!(out, Part(name, solid, fit(eng, solid), Primitive[], txt(p.labels)))
    end
    r = a.rete
    push!(out, Part("rete", r.solid, fit(r.engrave, r.solid), Primitive[], txt(r.labels)))
    ru = a.rule
    push!(
        out,
        Part(
            "rule",
            ru.solid,
            fit(Primitive[last(t) for t in ru.ticks], ru.solid),
            fit(Primitive[ru.fiducial], ru.solid),
            txt(ru.labels),
        ),
    )
    al = a.alidade
    push!(out, Part("alidade", al.solid, Primitive[], fit(al.fiducial, al.solid), Label[]))
    push!(out, Part("vane", al.vane, Primitive[], Primitive[], Label[]; quantity = 2))
    return out
end
