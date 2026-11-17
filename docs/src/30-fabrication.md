# [Fabrication](@id fabrication)

```julia
a = astrolabe(47.3; profile = LaserCut(thickness = 3))
verify(a)                       # includes the fabrication checks for the profile
render(a, "out")                # writes the files and parts.txt
```

## Profiles

| profile | for | output |
|---|---|---|
| [`LaserCut`](@ref) | acrylic, wood, card on a CO₂ laser | one SVG and one DXF per part, layers `CUT` (red hairline), `ENGRAVE` (black), `SCORE` (blue) |
| [`Metal`](@ref) | brass, steel, aluminium by fibre laser or waterjet, engraved or etched | cut and engrave layers in separate files (`*_cut.dxf`, `*_engrave.dxf`) |
| [`PCB`](@ref) | printed-circuit boards (e.g. ENIG gold on black mask) | DXF per KiCad layer: `Edge_Cuts`, `F_Cu`, `F_SilkS` |
| [`Paper`](@ref) | a 1:1 print to check fit and legibility | SVG with a 100 mm calibration bar |

Each profile carries the shop's limits in millimetres: minimum feature (`min_feature`),
spacing (`min_space`), text height (`min_text`), the pin diameter and clearances, the
margin between engraving and a cut edge, and the kerf. Override any of them:

```julia
Metal(thickness = 1.5, min_feature = 1.5, min_text = 2.5)
```

Most services compensate for the kerf themselves; set `compensate_kerf = true` only if
yours asks for compensated paths.

## Ordering

- **Laser-cut acrylic or wood** (online laser services or a local maker space): upload the
  SVG or DXF per part. Services tell cut from engraving by colour or by layer; the
  defaults are red hairlines for cutting and black for vector engraving, and
  `LaserCut(colors = Dict(:cut => "#0000ff", ...))` changes them to match your service.
  Use 3 mm sheet for the mater, limb and plates; the rete, rule and alidade can be 2–3 mm.
- **Brass or steel** (online sheet-metal services): upload `*_cut.dxf` for cutting. Many
  such services cut only, so engrave or etch `*_engrave.dxf` separately, or choose a
  service that does both. Choose 1–1.5 mm brass; the `Metal` profile keeps every hole at
  least the sheet thickness and every bridge at least 1 mm.
- **PCB** (e.g. JLCPCB, PCBWay, OSH Park): in KiCad, import each DXF onto its layer
  (File → Import → Graphics), then plot Gerbers. Ask for ENIG finish and no solder mask
  over `F_Cu` (or draw a mask opening) for gold lines.

Read the service's design rules and compare them with the profile before ordering;
`verify(a)` reports the narrowest bridge, smallest hole and smallest text against the
profile.

## Assembly

`parts.txt` lists the parts. From front to back on the central pin (an M3 bolt or a
rivet by default): rule, rete, plate(s) inside the limb ring, mater, alidade. The limb
ring is glued or riveted onto the mater; its tab keys the plates so the meridian stays
upright. The vanes press into the alidade's slots. With several plates, plain spacer
rings raise the limb to the height of the stack.

The mater's back is drawn as seen from the back, so engrave it face up.

## One-piece mater (3D printing, milling)

A historical mater is one piece: a thick disk with a pocket in its front for the plates,
the raised rim around it being the limb. Sheet processes can only cut through, so by
default the mater is a flat disk with the limb ring glued on top. A 3D printer or a mill
can make the pocket directly:

```julia
a = astrolabe(47.3; mater = :single)
render(a, "out")
```

Then `mater.dxf` carries the outline on `CUT` and the pocket outline (with the key tab
that keeps the plates upright) on `POCKET`, and `parts.txt` gives the total thickness and
the pocket's depth: one sheet thickness per plate. `mater_front` is not a piece of its
own but the artwork for the front face around the pocket (the hour and degree scales),
to engrave there or print and glue on.

In a CAD program such as Fusion: import `mater.dxf`, extrude the outline by the total
thickness, then cut the `POCKET` profile into the front face by the pocket depth. Mind
that `mater.dxf` is drawn as seen from the back, so its front face is the one facing away
from you.

## The rule and the alidade

Both are counterchanged, as on historical instruments. One straight edge runs the full
length through the pin and is the reading line. The bar lies on one side of it in the
upper half and on the other side in the lower half, so the ticks you read are always in
view beside the edge, even in opaque material. The two halves balance on the pin.

The sight vanes stand in a ring on the back that is left blank, so they never hide a
reading. Only inside that ring does the alidade widen into a small pad that spans the
edge; each vane, no wider than the bar, stands on its pad centred over the edge, with its
pinhole right over it. The line of sight is then the reading line.

## Sighting

Hang the instrument from its shackle so that the altitude scale's horizontal diameter is
level. Everything that turns on the pin balances except the rete, whose star pointers
and off-centre ecliptic put its centre of mass a few millimetres off the pin. Before
sighting, park the rete: `parts.txt` names the point of the ecliptic to turn straight
down, which [`balanced_rete_longitude`](@ref) also returns. Or loosen the nut so the rete
hangs free and settles there by itself. Left elsewhere, it tilts the instrument by up to
about half a degree on a 150 mm instrument cut from one sheet, and every altitude is off
by as much. [`hanging_tilt`](@ref) gives the tilt for any setting. A heavier mater
(thicker sheet, or solid infill on a 3D print) reduces it.

## Before you order

Print the `Paper` profile at 100 % and measure the calibration bar, then cut the parts
out and check the fit: the rete should turn freely inside the limb, the plate notch
should meet the tab, and the text should be legible at the size you chose. A larger
`diameter_mm` gives more stars, more legible text and finer scales.
