# A single-stroke engraving font. Labels become ordinary line geometry, so they can be
# engraved, etched or cut on any platform, and their size can be verified.
#
# Glyphs live on a grid 4 units wide and 6 units tall (the cap height), with an advance
# of 6 units. Lower-case input is drawn in capitals; diacritics are stripped.

const GLYPH_W = 4.0
const GLYPH_H = 6.0
const GLYPH_ADVANCE = 6.0

const _O = [(1, 0), (0, 1), (0, 5), (1, 6), (3, 6), (4, 5), (4, 1), (3, 0), (1, 0)]
const _P = [(0, 0), (0, 6), (3, 6), (4, 5), (4, 4), (3, 3), (0, 3)]
_DOT(y) = [(1.6, y), (2.4, y), (2.4, y + 0.8), (1.6, y + 0.8), (1.6, y)]

const GLYPHS = Dict{Char,Vector{Vector{Tuple{Float64,Float64}}}}(
    '0' => [_O, [(1, 1), (3, 5)]],
    '1' => [[(1, 5), (2, 6), (2, 0)], [(1, 0), (3, 0)]],
    '2' => [[(0, 5), (1, 6), (3, 6), (4, 5), (4, 4), (0, 0), (4, 0)]],
    '3' => [
        [
            (0, 5),
            (1, 6),
            (3, 6),
            (4, 5),
            (4, 4),
            (3, 3),
            (4, 2),
            (4, 1),
            (3, 0),
            (1, 0),
            (0, 1),
        ],
        [(1, 3), (3, 3)],
    ],
    '4' => [[(3, 0), (3, 6), (0, 2), (4, 2)]],
    '5' => [[(4, 6), (0, 6), (0, 3), (3, 3), (4, 2), (4, 1), (3, 0), (1, 0), (0, 1)]],
    '6' => [[
        (4, 5),
        (3, 6),
        (1, 6),
        (0, 5),
        (0, 1),
        (1, 0),
        (3, 0),
        (4, 1),
        (4, 2),
        (3, 3),
        (0, 3),
    ]],
    '7' => [[(0, 6), (4, 6), (1, 0)]],
    '8' => [[
        (1, 3),
        (0, 4),
        (0, 5),
        (1, 6),
        (3, 6),
        (4, 5),
        (4, 4),
        (3, 3),
        (1, 3),
        (0, 2),
        (0, 1),
        (1, 0),
        (3, 0),
        (4, 1),
        (4, 2),
        (3, 3),
    ]],
    '9' => [[
        (0, 1),
        (1, 0),
        (3, 0),
        (4, 1),
        (4, 5),
        (3, 6),
        (1, 6),
        (0, 5),
        (0, 4),
        (1, 3),
        (4, 3),
    ]],
    'A' => [[(0, 0), (0, 4), (2, 6), (4, 4), (4, 0)], [(0, 3), (4, 3)]],
    'B' => [
        [(0, 0), (0, 6), (3, 6), (4, 5), (4, 4), (3, 3), (0, 3)],
        [(3, 3), (4, 2), (4, 1), (3, 0), (0, 0)],
    ],
    'C' => [[(4, 5), (3, 6), (1, 6), (0, 5), (0, 1), (1, 0), (3, 0), (4, 1)]],
    'D' => [[(0, 0), (0, 6), (2, 6), (4, 4), (4, 2), (2, 0), (0, 0)]],
    'E' => [[(4, 6), (0, 6), (0, 0), (4, 0)], [(0, 3), (3, 3)]],
    'F' => [[(4, 6), (0, 6), (0, 0)], [(0, 3), (3, 3)]],
    'G' => [[
        (4, 5),
        (3, 6),
        (1, 6),
        (0, 5),
        (0, 1),
        (1, 0),
        (3, 0),
        (4, 1),
        (4, 3),
        (2, 3),
    ]],
    'H' => [[(0, 0), (0, 6)], [(4, 0), (4, 6)], [(0, 3), (4, 3)]],
    'I' => [[(1, 6), (3, 6)], [(2, 6), (2, 0)], [(1, 0), (3, 0)]],
    'J' => [[(4, 6), (4, 1), (3, 0), (1, 0), (0, 1)]],
    'K' => [[(0, 0), (0, 6)], [(4, 6), (0, 2)], [(1, 3), (4, 0)]],
    'L' => [[(0, 6), (0, 0), (4, 0)]],
    'M' => [[(0, 0), (0, 6), (2, 3), (4, 6), (4, 0)]],
    'N' => [[(0, 0), (0, 6), (4, 0), (4, 6)]],
    'O' => [_O],
    'P' => [_P],
    'Q' => [_O, [(2, 2), (4, 0)]],
    'R' => [_P, [(2, 3), (4, 0)]],
    'S' => [[
        (4, 5),
        (3, 6),
        (1, 6),
        (0, 5),
        (0, 4),
        (1, 3),
        (3, 3),
        (4, 2),
        (4, 1),
        (3, 0),
        (1, 0),
        (0, 1),
    ]],
    'T' => [[(0, 6), (4, 6)], [(2, 6), (2, 0)]],
    'U' => [[(0, 6), (0, 1), (1, 0), (3, 0), (4, 1), (4, 6)]],
    'V' => [[(0, 6), (2, 0), (4, 6)]],
    'W' => [[(0, 6), (1, 0), (2, 3), (3, 0), (4, 6)]],
    'X' => [[(0, 0), (4, 6)], [(0, 6), (4, 0)]],
    'Y' => [[(0, 6), (2, 3), (4, 6)], [(2, 3), (2, 0)]],
    'Z' => [[(0, 6), (4, 6), (0, 0), (4, 0)]],
    '-' => [[(1, 3), (3, 3)]],
    '+' => [[(1, 3), (3, 3)], [(2, 2), (2, 4)]],
    '.' => [_DOT(0)],
    ',' => [[(2.4, 0.8), (2.4, 0), (1.6, -1)]],
    ':' => [_DOT(0.6), _DOT(4)],
    '\'' => [[(2.2, 6), (1.8, 4.6)]],
    '"' => [[(1.4, 6), (1.0, 4.6)], [(2.8, 6), (2.4, 4.6)]],
    '°' => [[
        (1, 4.5),
        (1, 5.5),
        (1.5, 6),
        (2.5, 6),
        (3, 5.5),
        (3, 4.5),
        (2.5, 4),
        (1.5, 4),
        (1, 4.5),
    ]],
    '/' => [[(0, 0), (4, 6)]],
    '(' => [[(3, 6), (2, 5), (2, 1), (3, 0)]],
    ')' => [[(1, 6), (2, 5), (2, 1), (1, 0)]],
    '=' => [[(1, 2), (3, 2)], [(1, 4), (3, 4)]],
    '*' => [[(2, 1.5), (2, 4.5)], [(0.8, 2.3), (3.2, 3.7)], [(0.8, 3.7), (3.2, 2.3)]],
    ' ' => Vector{Tuple{Float64,Float64}}[],
)

# characters folded onto the glyph set
const GLYPH_ALIASES = Dict(
    '−' => '-',
    '–' => '-',
    '′' => '\'',
    '″' => '"',
    'ʿ' => '\'',
    'ʾ' => '\'',
    '’' => '\'',
    '‘' => '\'',
    'º' => '°',
)

"Normalise a string to the characters the stroke font can draw."
function font_text(s::AbstractString)
    t = Base.Unicode.normalize(String(s); stripmark = true)
    io = IOBuffer()
    for ch in t
        ch = get(GLYPH_ALIASES, ch, ch)
        ch = uppercase(ch)
        haskey(GLYPHS, ch) || (ch = '*')
        print(io, ch)
    end
    return String(take!(io))
end

"""
    Label(text, pos, height; angle = 0, halign = :center, valign = :middle)

Engraved text in single-stroke capitals. `pos` is the anchor (plate units), `height` the
cap height (plate units) and `angle` the baseline direction (radians).
"""
struct Label
    text::String
    pos::Pt
    height::Float64
    angle::Float64
    halign::Symbol
    valign::Symbol
end
Label(
    text::AbstractString,
    pos::Pt,
    height::Real;
    angle::Real = 0.0,
    halign::Symbol = :center,
    valign::Symbol = :middle,
) = Label(font_text(text), pos, Float64(height), Float64(angle), halign, valign)

"Width of a label's text (plate units)."
label_width(l::Label) = text_width(l.text, l.height)
text_width(s::AbstractString, h::Real) =
    max(length(s) * GLYPH_ADVANCE - (GLYPH_ADVANCE - GLYPH_W), 0) * h / GLYPH_H

"""
    label_strokes(l::Label) -> Vector{Primitive}

The label as polylines.
"""
function label_strokes(l::Label)
    k = l.height / GLYPH_H
    w = label_width(l)
    x0 = l.halign === :left ? 0.0 : l.halign === :right ? -w : -w / 2
    y0 = l.valign === :bottom ? 0.0 : l.valign === :top ? -l.height : -l.height / 2
    out = Primitive[]
    for (i, ch) in enumerate(l.text)
        for stroke in GLYPHS[ch]
            pts = [
                l.pos +
                rotate(Pt(x0 + k * ((i - 1) * GLYPH_ADVANCE + x), y0 + k * y), l.angle)
                for (x, y) in stroke
            ]
            push!(out, Polyline(pts))
        end
    end
    return out
end

"Corners of the label's bounding box (plate units)."
function label_box(l::Label)
    w = label_width(l)
    x0 = l.halign === :left ? 0.0 : l.halign === :right ? -w : -w / 2
    y0 = l.valign === :bottom ? 0.0 : l.valign === :top ? -l.height : -l.height / 2
    return [
        l.pos + rotate(Pt(x, y), l.angle) for
        (x, y) in ((x0, y0), (x0 + w, y0), (x0 + w, y0 + l.height), (x0, y0 + l.height))
    ]
end

"Scale a label about the origin."
scale(l::Label, k::Real) =
    Label(l.text, k * l.pos, k * l.height, l.angle, l.halign, l.valign)
rotate(l::Label, θ::Real) =
    Label(l.text, rotate(l.pos, θ), l.height, l.angle + θ, l.halign, l.valign)
