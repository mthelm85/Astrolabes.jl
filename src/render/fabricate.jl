# Fabrication output: per-part SVG and DXF files in millimetres.

"A part laid out in millimetres, y up, one primitive list per layer."
struct Drawing
    name::String
    cut::Vector{Primitive}
    engrave::Vector{Primitive}
    score::Vector{Primitive}
    text::Vector{Primitive}
end

"""
    drawing(part, scale, profile; tol) -> Drawing

Convert a [`Part`](@ref) to millimetres. Labels become single-stroke text; with
`profile.compensate_kerf` the cut paths are offset outward by half the kerf.
"""
function drawing(part::Part, s::Real, profile::Profile; tol::Real = 2e-5)
    solid =
        profile.compensate_kerf ? shape_offset(part.solid, kerf(profile) / 2 / s; tol) :
        part.solid
    cut = Primitive[scale(p, s) for p in contour_prims(solid)]
    eng = Primitive[scale(p, s) for p in part.engrave]
    sc = Primitive[scale(p, s) for p in part.score]
    txt = Primitive[scale(p, s) for l in part.labels for p in label_strokes(l)]
    return Drawing(part.name, cut, eng, sc, txt)
end

function bounds(prims; tol = 1e-3)
    xs, ys = Float64[], Float64[]
    for p in prims, q in polyline_points(p; tol)
        push!(xs, q.x)
        push!(ys, q.y)
    end
    return minimum(xs), minimum(ys), maximum(xs), maximum(ys)
end

# ---------------------------------------------------------------------------- SVG

function write_svg(
    path::AbstractString,
    title::AbstractString,
    layers::Vector{<:Pair{String,<:AbstractVector{<:Primitive}}},
    colors::Vector{String},
    widths::Vector{Float64};
    margin = 3.0,
    calibration::Bool = false,
    background::Union{Nothing,String} = nothing,
)
    allp = reduce(vcat, [collect(Primitive, l[2]) for l in layers]; init = Primitive[])
    x1, y1, x2, y2 = bounds(allp)
    extra = Primitive[]
    if calibration
        # 100 mm bar with centimetre ticks under the drawing
        by = y1 - 8
        bx = (x1 + x2) / 2 - 50
        push!(extra, Segment(Pt(bx, by), Pt(bx + 100, by)))
        for k = 0:10
            push!(
                extra,
                Segment(Pt(bx + 10k, by), Pt(bx + 10k, by + (k % 5 == 0 ? 3 : 1.8))),
            )
        end
        lab = Label("100 MM - PRINT AT 100 %", Pt(bx + 50, by - 4), 2.5)
        append!(extra, label_strokes(lab))
        x1, y1 = min(x1, bx), by - 6
        x2 = max(x2, bx + 100)
    end
    w, h = x2 - x1 + 2margin, y2 - y1 + 2margin
    t = SvgXform(1.0)
    open(path, "w") do io
        println(io, "<?xml version=\"1.0\" encoding=\"UTF-8\"?>")
        println(
            io,
            "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"",
            fmt(w),
            "mm\" height=\"",
            fmt(h),
            "mm\" viewBox=\"",
            fmt(x1 - margin),
            " ",
            fmt(-y2 - margin),
            " ",
            fmt(w),
            " ",
            fmt(h),
            "\">",
        )
        println(io, "  <title>", title, "</title>")
        background === nothing || println(
            io,
            "  <rect x=\"",
            fmt(x1 - margin),
            "\" y=\"",
            fmt(-y2 - margin),
            "\" width=\"",
            fmt(w),
            "\" height=\"",
            fmt(h),
            "\" rx=\"4\" fill=\"",
            background,
            "\"/>",
        )
        for ((name, prims), c, sw) in zip(layers, colors, widths)
            isempty(prims) && continue
            println(
                io,
                "  <g id=\"",
                name,
                "\" fill=\"none\" stroke=\"",
                c,
                "\" stroke-width=\"",
                fmt(sw),
                "\" stroke-linecap=\"round\" stroke-linejoin=\"round\">",
            )
            for p in prims
                svg_element(io, p, t)
            end
            println(io, "  </g>")
        end
        if !isempty(extra)
            println(
                io,
                "  <g id=\"calibration\" fill=\"none\" stroke=\"#000000\" stroke-width=\"0.2\">",
            )
            foreach(p -> svg_element(io, p, t), extra)
            println(io, "  </g>")
        end
        println(io, "</svg>")
    end
    return path
end

# ---------------------------------------------------------------------------- DXF (R12 ASCII)

dxf_pair(io, code, value) = (println(io, code); println(io, value))
dxf_num(x) = @sprintf("%.6f", x)

function dxf_entity(io, c::Circle, layer)
    dxf_pair(io, 0, "CIRCLE")
    dxf_pair(io, 8, layer)
    dxf_pair(io, 10, dxf_num(c.c.x))
    dxf_pair(io, 20, dxf_num(c.c.y))
    dxf_pair(io, 30, "0.0")
    dxf_pair(io, 40, dxf_num(c.r))
end
function dxf_entity(io, a::Arc, layer)
    dxf_pair(io, 0, "ARC")
    dxf_pair(io, 8, layer)
    dxf_pair(io, 10, dxf_num(a.c.x))
    dxf_pair(io, 20, dxf_num(a.c.y))
    dxf_pair(io, 30, "0.0")
    dxf_pair(io, 40, dxf_num(a.r))
    dxf_pair(io, 50, dxf_num(mod(rad2deg(a.θ1), 360)))
    dxf_pair(io, 51, dxf_num(mod(rad2deg(a.θ2), 360)))
end
function dxf_entity(io, s::Segment, layer)
    dxf_pair(io, 0, "LINE")
    dxf_pair(io, 8, layer)
    dxf_pair(io, 10, dxf_num(s.a.x))
    dxf_pair(io, 20, dxf_num(s.a.y))
    dxf_pair(io, 30, "0.0")
    dxf_pair(io, 11, dxf_num(s.b.x))
    dxf_pair(io, 21, dxf_num(s.b.y))
    dxf_pair(io, 31, "0.0")
end
function dxf_entity(io, pl::Polyline, layer)
    dxf_pair(io, 0, "POLYLINE")
    dxf_pair(io, 8, layer)
    dxf_pair(io, 66, 1)
    dxf_pair(io, 10, "0.0")
    dxf_pair(io, 20, "0.0")
    dxf_pair(io, 30, "0.0")
    dxf_pair(io, 70, pl.closed ? 1 : 0)
    for p in pl.pts
        dxf_pair(io, 0, "VERTEX")
        dxf_pair(io, 8, layer)
        dxf_pair(io, 10, dxf_num(p.x))
        dxf_pair(io, 20, dxf_num(p.y))
        dxf_pair(io, 30, "0.0")
    end
    dxf_pair(io, 0, "SEQEND")
    dxf_pair(io, 8, layer)
end
dxf_entity(io, ::Line, layer) = throw(ArgumentError("cannot write an infinite Line"))

const DXF_COLORS = Dict(
    "CUT" => 1,
    "ENGRAVE" => 7,
    "SCORE" => 5,
    "TEXT" => 7,
    "Edge_Cuts" => 2,
    "F_Cu" => 1,
    "F_SilkS" => 7,
)

"""
    write_dxf(path, layers)

Write an AutoCAD R12 ASCII DXF in millimetres; `layers` is a list of
`layer name => primitives`.
"""
function write_dxf(
    path::AbstractString,
    layers::Vector{<:Pair{String,<:AbstractVector{<:Primitive}}},
)
    open(path, "w") do io
        dxf_pair(io, 0, "SECTION")
        dxf_pair(io, 2, "HEADER")
        dxf_pair(io, 9, "\$ACADVER")
        dxf_pair(io, 1, "AC1009")
        dxf_pair(io, 9, "\$INSUNITS")
        dxf_pair(io, 70, 4)
        dxf_pair(io, 0, "ENDSEC")
        dxf_pair(io, 0, "SECTION")
        dxf_pair(io, 2, "TABLES")
        dxf_pair(io, 0, "TABLE")
        dxf_pair(io, 2, "LAYER")
        dxf_pair(io, 70, length(layers))
        for (name, _) in layers
            dxf_pair(io, 0, "LAYER")
            dxf_pair(io, 2, name)
            dxf_pair(io, 70, 0)
            dxf_pair(io, 62, get(DXF_COLORS, name, 7))
            dxf_pair(io, 6, "CONTINUOUS")
        end
        dxf_pair(io, 0, "ENDTAB")
        dxf_pair(io, 0, "ENDSEC")
        dxf_pair(io, 0, "SECTION")
        dxf_pair(io, 2, "ENTITIES")
        for (name, prims) in layers, p in prims
            dxf_entity(io, p, name)
        end
        dxf_pair(io, 0, "ENDSEC")
        dxf_pair(io, 0, "EOF")
    end
    return path
end

# ---------------------------------------------------------------------------- per profile

cut_width(::Profile) = 0.01
cut_width(p::Paper) = p.stroke

function write_part(dir, d::Drawing, profile::Profile, formats)
    out = String[]
    c = profile.colors
    sw = stroke_width(profile)
    marks = Primitive[d.engrave; d.text]
    if profile isa PCB
        layers = ["Edge_Cuts" => d.cut, "F_Cu" => [d.engrave; d.score], "F_SilkS" => d.text]
        if :dxf in formats
            for l in layers
                push!(out, write_dxf(joinpath(dir, "$(d.name)-$(l[1]).dxf"), [l]))
            end
        end
        :svg in formats && push!(
            out,
            write_svg(
                joinpath(dir, "$(d.name).svg"),
                d.name,
                layers,
                [c[:cut], c[:engrave], "#ffffff"],
                [0.05, profile.min_trace, profile.silk_width],
            ),
        )
    elseif split_layers(profile)
        groups = [
            ("cut", ["CUT" => d.cut], [c[:cut]], [cut_width(profile)]),
            (
                "engrave",
                ["ENGRAVE" => marks, "SCORE" => d.score],
                [c[:engrave], c[:score]],
                [sw, sw],
            ),
        ]
        for (suffix, layers, cols, ws) in groups
            all(isempty(l[2]) for l in layers) && continue
            :dxf in formats &&
                push!(out, write_dxf(joinpath(dir, "$(d.name)_$suffix.dxf"), layers))
            :svg in formats && push!(
                out,
                write_svg(
                    joinpath(dir, "$(d.name)_$suffix.svg"),
                    "$(d.name) $suffix",
                    layers,
                    cols,
                    ws,
                ),
            )
        end
    else
        layers = ["CUT" => d.cut, "ENGRAVE" => marks, "SCORE" => d.score]
        cols = [c[:cut], c[:engrave], c[:score]]
        ws = [cut_width(profile), sw, sw]
        :dxf in formats && push!(out, write_dxf(joinpath(dir, "$(d.name).dxf"), layers))
        :svg in formats && push!(
            out,
            write_svg(
                joinpath(dir, "$(d.name).svg"),
                d.name,
                layers,
                cols,
                ws;
                calibration = profile isa Paper,
            ),
        )
    end
    return out
end

"""
    render(a::Astrolabe, dir; profile = a.profile, formats = (:svg, :dxf)) -> Vector{String}

Write the fabrication files for every part into `dir` and a `parts.txt` with the bill of
materials and assembly notes. Returns the paths written.

- `LaserCut`: one SVG and one DXF per part, layers `CUT` (red hairline), `ENGRAVE`
  (black) and `SCORE` (blue).
- `Metal`: cut and engrave layers in separate files (`*_cut`, `*_engrave`).
- `PCB`: DXF per KiCad layer (`Edge_Cuts`, `F_Cu`, `F_SilkS`) for import into KiCad,
  plus a preview SVG.
- `Paper`: a 1:1 SVG proof per part with a 100 mm calibration bar (no DXF).

The geometry is written exactly as computed; run [`verify`](@ref) first, which also
runs the fabrication checks for the profile.
"""
function render(
    a::Astrolabe,
    dir::AbstractString;
    profile::Profile = a.profile,
    formats = profile isa Paper ? (:svg,) : (:svg, :dxf),
    tol::Real = 2e-5,
)
    mkpath(dir)
    out = String[]
    ps = parts(a; tol)
    for p in ps
        append!(out, write_part(dir, drawing(p, a.scale, profile; tol), profile, formats))
    end
    push!(out, write_bom(joinpath(dir, "parts.txt"), a, ps, profile))
    return out
end

function write_bom(path, a::Astrolabe, ps::Vector{Part}, profile::Profile)
    open(path, "w") do io
        println(io, "Astrolabe parts — ", a)
        println(
            io,
            "Profile: ",
            profile_name(profile),
            ", material thickness ",
            profile.thickness,
            " mm",
        )
        println(io)
        println(io, rpad("part", 16), rpad("qty", 5), rpad("size (mm)", 18), "notes")
        for p in ps
            x1, y1, x2, y2 = bounds(contour_prims(p.solid))
            sz = @sprintf("%.1f x %.1f", (x2 - x1) * a.scale, (y2 - y1) * a.scale)
            note =
                p.face === :back ? "engrave the back face (drawn as seen from the back)" :
                p.name == "limb" ?
                "glued or riveted onto the mater; the tab keys the plates" :
                p.name == "limb_spacer" ? "plain ring under the engraved limb" :
                p.name == "vane" ? "sight vanes; tabs press into the alidade slots" : ""
            println(io, rpad(p.name, 16), rpad(string(p.quantity), 5), rpad(sz, 18), note)
        end
        println(io)
        println(
            io,
            "Assembly, front to back on the pin (",
            @sprintf("%.1f", profile.pin_diameter),
            " mm, e.g. an M",
            round(Int, profile.pin_diameter),
            " bolt or a rivet):",
        )
        println(io, "  rule, rete, plate(s) inside the limb ring, mater, alidade.")
        println(
            io,
            "The plates' notch fits the limb's key tab, so the meridian stays upright.",
        )
        a.location === nothing || println(
            io,
            @sprintf(
                "Hour scale set for longitude %.4f°, time zone UTC%+.4g h.",
                a.location.longitude,
                a.location.timezone
            )
        )
    end
    return path
end

"""
    render_preview(a::Astrolabe, path; side = :both, rete_rotation = 30,
                   rule_rotation = -50, alidade_rotation = 35) -> String

An assembled view of the instrument as one SVG, for documentation; not for fabrication.
`side = :front` shows the mater, limb, first plate, the rete and the rule; `:back` the
back of the mater with the alidade; `:both` the two faces side by side. Rotations are in
degrees.
"""
function render_preview(
    a::Astrolabe,
    path::AbstractString;
    side::Symbol = :both,
    rete_rotation::Real = 30.0,
    rule_rotation::Real = -50.0,
    alidade_rotation::Real = 35.0,
    tol::Real = 2e-5,
)
    side in (:front, :back, :both) ||
        throw(ArgumentError("side must be :front, :back or :both"))
    ps = Dict(p.name => p for p in parts(a; tol))
    s = a.scale
    θr, θu = deg2rad(rete_rotation), deg2rad(rule_rotation)
    θa = deg2rad(alidade_rotation)
    sc(prims) = Primitive[scale(p, s) for p in prims]
    txt(p) = Primitive[scale(q, s) for l in p.labels for q in label_strokes(l)]
    plate = ps[first(k for k in keys(ps) if startswith(k, "plate_"))]
    rete = ps["rete"]
    rule = ps["rule"]
    limb = ps["limb"]
    # previews only: drop polyline vertices closer than 0.15 mm (invisible at this scale)
    function thin(p::Polyline)
        pts = Pt[p.pts[1]]
        for q in p.pts[2:(end-1)]
            norm2(q - pts[end]) >= 0.15 && push!(pts, q)
        end
        push!(pts, p.pts[end])
        return Polyline(pts, p.closed)
    end
    thin(p::Primitive) = p
    rot(prims, θ) = Primitive[thin(rotate(p, θ)) for p in prims]
    mater = ps["mater"]
    alidade = ps["alidade"]
    outline = rot(sc(contour_prims(mater.solid)), 0.0)
    front = [
        "mater" => outline,
        "limb" =>
            rot([sc(limb.engrave); txt(limb); sc(contour_prims(limb.solid))], 0.0),
        "plate" => rot([sc(plate.engrave); txt(plate)], 0.0),
        "rete" => rot([sc(contour_prims(rete.solid)); sc(rete.engrave); txt(rete)], θr),
        "rule" => rot([sc(contour_prims(rule.solid)); sc(rule.engrave); txt(rule)], θu),
    ]
    back = [
        "mater_back" => outline,
        "back" => rot([sc(mater.engrave); txt(mater)], 0.0),
        "alidade" => rot([sc(contour_prims(alidade.solid)); sc(alidade.score)], θa),
    ]
    front_colors = ["#5a4a2a", "#3a2a10", "#55606e", "#a8321e", "#202020"]
    front_widths = [0.35, 0.2, 0.15, 0.3, 0.3]
    back_colors = ["#5a4a2a", "#3a2a10", "#202020"]
    back_widths = [0.35, 0.2, 0.3]
    layers, colors, widths = if side === :front
        front, front_colors, front_widths
    elseif side === :back
        back, back_colors, back_widths
    else
        # the back to the right of the front, with a gap of a tenth of the diameter
        shift = Pt(1.1 * a.diameter_mm, 0.0)
        moved = [k => Primitive[translate(p, shift) for p in v] for (k, v) in back]
        [front; moved], [front_colors; back_colors], [front_widths; back_widths]
    end
    # a parchment ground so the preview reads on light and dark pages alike
    write_svg(path, string(a), layers, colors, widths; background = "#f6efdf")
    # a preview needs no micrometre precision: keep the file small
    s = read(path, String)
    write(path, replace(s, r"(-?\d+\.\d\d)\d+" => s"\1"))
    return path
end
