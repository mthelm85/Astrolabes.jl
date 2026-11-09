# Minimal dependency-free SVG writer with fabrication layers.

const LAYER_STYLE = Dict(
    :cut => "stroke=\"#d00000\" stroke-width=\"0.1\"",
    :score => "stroke=\"#0050d0\" stroke-width=\"0.1\"",
    :engrave => "stroke=\"#000000\" stroke-width=\"0.2\"",
    :guide => "stroke=\"#909090\" stroke-width=\"0.1\"",
)
const LAYER_ORDER = (:guide, :engrave, :score, :cut)

fmt(x) = @sprintf("%.4f", x)

# plate units → mm, y flipped so the drawing reads like the math (y up)
struct SvgXform
    s::Float64
end
(t::SvgXform)(p::Pt) = (t.s * p.x, -t.s * p.y)

function svg_element(io::IO, c::Circle, t::SvgXform)
    x, y = t(c.c)
    println(
        io,
        "    <circle cx=\"",
        fmt(x),
        "\" cy=\"",
        fmt(y),
        "\" r=\"",
        fmt(t.s * c.r),
        "\"/>",
    )
end

function svg_element(io::IO, a::Arc, t::SvgXform)
    # split into ≤ 180° pieces; a counter-clockwise arc in y-up coordinates is drawn
    # with sweep-flag 0 in SVG's y-down space
    k = max(1, ceil(Int, (a.θ2 - a.θ1) / π))
    x0, y0 = t(arc_point(a, a.θ1))
    print(io, "    <path d=\"M ", fmt(x0), " ", fmt(y0))
    for i = 1:k
        x, y = t(arc_point(a, a.θ1 + (a.θ2 - a.θ1) * i / k))
        r = fmt(t.s * a.r)
        print(io, " A ", r, " ", r, " 0 0 0 ", fmt(x), " ", fmt(y))
    end
    println(io, "\"/>")
end

function svg_element(io::IO, s::Segment, t::SvgXform)
    (x1, y1), (x2, y2) = t(s.a), t(s.b)
    println(
        io,
        "    <line x1=\"",
        fmt(x1),
        "\" y1=\"",
        fmt(y1),
        "\" x2=\"",
        fmt(x2),
        "\" y2=\"",
        fmt(y2),
        "\"/>",
    )
end

function svg_element(io::IO, pl::Polyline, t::SvgXform)
    pts = join((join(fmt.(t(p)), ",") for p in pl.pts), " ")
    tag = pl.closed ? "polygon" : "polyline"
    println(io, "    <", tag, " points=\"", pts, "\"/>")
end

svg_element(::IO, ::Line, ::SvgXform) =
    throw(ArgumentError("cannot render an infinite Line; clip it first"))

"""
    render_svg(plate::Plate, path; diameter_mm = 150, margin_mm = 5) -> String

Write `plate` as a layered SVG (groups `cut`, `score`, `engrave`, `guide`) scaled so the
limb has diameter `diameter_mm`. Returns `path`.
"""
function render_svg(
    plate::Plate,
    path::AbstractString;
    diameter_mm::Real = 150,
    margin_mm::Real = 5,
)
    t = SvgXform((diameter_mm / 2) / limb_radius(plate))
    half = diameter_mm / 2 + margin_mm
    open(path, "w") do io
        println(io, "<?xml version=\"1.0\" encoding=\"UTF-8\"?>")
        println(
            io,
            "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"",
            fmt(2half),
            "mm\" height=\"",
            fmt(2half),
            "mm\" viewBox=\"",
            fmt(-half),
            " ",
            fmt(-half),
            " ",
            fmt(2half),
            " ",
            fmt(2half),
            "\">",
        )
        println(
            io,
            "  <title>",
            @sprintf("Astrolabe plate, latitude %.4g°", plate.latitude),
            "</title>",
        )
        for layer in LAYER_ORDER
            els = filter(e -> e.layer === layer, plate.elements)
            isempty(els) && continue
            println(io, "  <g id=\"", layer, "\" fill=\"none\" ", LAYER_STYLE[layer], ">")
            for el in els, p in el.prims
                svg_element(io, p, t)
            end
            println(io, "  </g>")
        end
        println(io, "</svg>")
    end
    return path
end
