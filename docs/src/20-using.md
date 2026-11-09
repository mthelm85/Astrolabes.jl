# [Using the library](@id using)

## Building an instrument

```julia
using Astrolabes

a = astrolabe(51.5)                        # London, epoch 2026, 150 mm, laser cut
a = astrolabe("33°52′S"; diameter_mm = 200)
a = astrolabe(47.3; latitudes = (46.0, 48.5))   # three plates (same hemisphere)
```

Main keywords of [`astrolabe`](@ref):

| keyword | default | meaning |
|---|---|---|
| `epoch` | `2026.0` | Julian year or [`Epoch`](@ref); before 1582.8 the calendar is Julian |
| `diameter_mm` | `150` | diameter of the mater |
| `profile` | `LaserCut()` | fabrication profile |
| `latitudes` | `()` | extra plates |
| `longitude`, `timezone` | none | turn the hour scale to read zone time |
| `stars` | `:default` | `:all`, a list of names, or a `Vector{Star}` |
| `names` | `:iau` | or `:traditional` |
| `almucantar_step`, `azimuth_step` | `2`, `10` | degrees |
| `twilight` | `(-18,)` | altitudes of twilight lines |
| `unequal_hours` | `:exact` | `:circles`, `:none` |
| `calendar` | `:concentric` | `:eccentric` |
| `shadow_base` | `12` | or `7` |
| `sine_quadrant` | `false` | replaces the left half of the unequal hours |
| `hours` | `:h24` | or `:h12` |
| `rete_style` | from the profile | [`ReteStyle`](@ref) widths in mm |

## Stars

```julia
catalog_stars(:all)            # the 59 catalogue stars
find_star("Aldebaran")
traditional_name("Aldebaran")
a.rete.pointers                # what was placed, and how (:pointer, :marker, :notch)
a.rete.skipped                 # what was left out, and why
```

A custom `Star(name, ra, dec; pmra, pmdec, parallax, rv, vmag)` (J2000, ICRS, degrees
and mas/yr) can be given in `stars`.

## A historical instrument

```julia
chaucer = astrolabe(51.75; epoch = 1391.0, calendar = :eccentric, names = :traditional)
```

Precession, proper motion and obliquity are evaluated for 1391, the calendar on the back
is Julian, and the eccentric calendar follows the medieval construction.

## Plates on their own

```julia
p = Plate(47.3; almucantar_step = 5, twilight = (-6, -12, -18))
verify(p)
render_svg(p, "plate.svg"; diameter_mm = 150)
```

## Operating the instrument

```julia
sim = simulate(a)
sunrise(sim, (6, 21))                    # (apparent, clock, mean) hours
star_transit(sim, "Sirius", (1, 1))
time_from_altitude(sim, :Sun, 20, (3, 20); side = :east)
sunrise_azimuth(sim, (6, 21))
eot_reading(sim, (11, 3))                # minutes
```

`apparent` is local apparent solar time; `clock` the reading of the limb (zone time
before the equation of time, if the instrument was built with `longitude`/`timezone`);
`mean` the clock reading corrected with the equation of time read from the back.
