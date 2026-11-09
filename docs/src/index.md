```@meta
CurrentModule = Astrolabes
```

# Astrolabes.jl

Geometrically exact, fabrication-ready astrolabes for any latitude and epoch — with
built-in verification: every drawn line is checked against spherical astronomy.

!!! note "Work in progress"
    Implemented so far: the astronomy layer (epochs, long-term precession and obliquity via
    SOFA.jl, a Meeus solar model and equation of time), the 2-D primitives, the
    stereographic projection, the sample-and-project verification harness, and plates with
    the equator, tropics, limb, horizon and almucantars.

## Quick start

```julia
using Astrolabes

plate = Plate(47.3)          # or Plate("47°18′N")
verify(plate)                # forward + backward sampling checks on every line
render_svg(plate, "plate.svg"; diameter_mm = 150)
```

## How verification works

Plate lines are drawn from closed-form formulas. Each line is then checked two ways
with independent machinery:

- **sphere → plate:** sample the defining set on the celestial sphere (for an almucantar,
  every azimuth at that altitude, converted with SOFA's `ae2hd`), project each point, and
  measure its distance to the drawn primitive;
- **plate → sphere:** sample the drawn primitive, un-project each point and evaluate the
  defining equation (e.g. its altitude, via SOFA's `hd2ae`).

The first catches wrong curves; the second also catches extra geometry such as a line that
was not clipped to the limb.

## Conventions

- Degrees at the public API; radians internally.
- Plate geometry uses equator radius `R = 1`; millimetres only when rendering.
- Northern plates project from the south celestial pole: east on the left, the rete turns
  clockwise. Southern plates project from the north celestial pole and are mirrored, so the
  plate for −φ is the mirror image of the plate for +φ.
