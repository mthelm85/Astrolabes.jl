# [How it works](@id how)

## The projection

An astrolabe is a map of the sky on the plane of the celestial equator, drawn by
**stereographic projection** from the south celestial pole (for a northern instrument).
A point of hour angle ``H`` and declination ``δ`` has the direction
``v = (\cos δ \sin H,\ \cos δ \cos H,\ \sin δ)`` and lands at

```math
p = R\,\frac{(v_x, v_y)}{1 + v_z}.
```

Stereographic projection maps every circle on the sphere to a circle (or a line) on the
plate and preserves angles, so almost every line on the instrument is a circle with a
closed-form centre and radius. The radius of the declination circle ``δ`` is
``R \tan\frac{90° - δ}{2}``: the equator has radius ``R``, the tropic of Cancer is smaller
and the tropic of Capricorn, the edge of the plate, is larger.

## The plate

A plate belongs to one latitude ``φ``. Its lines are fixed in the sky of the observer:

| line | definition on the sphere | on the plate |
|---|---|---|
| horizon | altitude 0 | circle, centre ``(0, \cot φ)``, radius ``1/\sin φ`` |
| almucantar ``a`` | altitude ``a`` | circle through ``y = -\tan\frac{φ-a}{2}`` and ``\cot\frac{φ+a}{2}`` |
| azimuth ``A`` | vertical circle through the zenith | circle, centre ``(\cot A / \cos φ, -\tan φ)`` |
| twilight | altitude −18° (−12°, −6°) | as an almucantar |
| unequal hour ``k`` | the Sun's hour angle ``H_s + k(360° - 2H_s)/12`` below the horizon | curve, computed exactly |

The unequal (seasonal) hours divide the night into twelve parts whatever its length.
Many instruments draw them as circular arcs through three points; `Plate` draws the exact
curve by default (`unequal_hours = :exact`) and the arcs on request (`:circles`).

## The rete

The rete is the star map that turns over the plate once a day. It carries the ecliptic,
which is the circle through the solstice points, graduated in degrees of longitude, and pointers to
bright stars. Star positions come from the Hipparcos new reduction (van Leeuwen 2007),
moved to the instrument's epoch with proper motion (SOFA `pmsafe`) and the long-term
precession model of Vondrák et al. (2011) (SOFA `ltp`). The obliquity of the ecliptic
follows from the same model, so a 1391 instrument has a slightly larger ecliptic than a
2026 one.

The rete is laid out automatically, brightest stars first. A star in open space gets a
pointer that runs to the structure; if its name fits, the pointer is lengthened along the
best free direction to carry it. A star under the structure gets an engraved marker. A
star on the very edge gets a small V-notch with the star at its apex, as on many
medieval retes. Stars that would collide with a brighter one are skipped and listed in
`rete.skipped`.

## The mater and the back

The limb carries the hour scale. The rule laid over the Sun's place on the ecliptic reads
apparent solar time; with `longitude` and `timezone` the scale is turned so that it reads
zone time before the equation of time. The back carries:

- the **altitude scale** used with the alidade to take the Sun's or a star's altitude;
- the **zodiac** and **calendar**: laying the alidade on the date gives the Sun's
  longitude. The calendar is computed for noon on each day of the epoch's year from the
  solar model. `calendar = :eccentric` draws the medieval eccentric calendar instead (an
  approximation within 0.1°);
- the **equation of time** as a curve read with the alidade (minutes, apparent − mean);
- the **shadow square** (base 12 or 7) for heights and distances;
- the **unequal hours** quadrant and, optionally, a **sine quadrant**.

## Using the instrument

To find the time of sunrise: set the alidade on the date and read the Sun's longitude;
find that longitude on the rete's ecliptic; turn the rete until that point meets the
horizon on the east side; lay the rule over it and read the hour on the limb.
[`simulate`](@ref) does exactly this with the drawn primitives; see
[Verification](@ref verification).
