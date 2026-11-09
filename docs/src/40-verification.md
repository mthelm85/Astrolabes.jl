# [Verification](@id verification)

`verify(a)` returns a [`VerificationReport`](@ref): one line per check with the number of
samples, the largest error and the tolerance. Every check must pass; the gallery and the
test suite enforce this.

## Geometry: both directions

Each plate line is drawn from closed-form formulas and then checked with independent
machinery:

- **sphere → plate:** sample the defining set on the celestial sphere (for an almucantar,
  every azimuth at that altitude, converted with SOFA's `ae2hd`), project each point, and
  measure its distance to the drawn primitive;
- **plate → sphere:** sample the drawn primitive, un-project each point, and evaluate the
  defining equation there (its altitude, via SOFA's `hd2ae`).

The first catches a wrong curve; the second also catches extra geometry, such as a line
not clipped to the limb. The tolerance is ``10^{-9}`` (in units of the equator radius,
that is 60 nm on a 150 mm instrument).

The same is done for the rete's ecliptic, its graduations (longitude recovered from each
tick) and every star (the tip, un-projected, against the precessed catalogue position), for
the limb's hour and degree scales, the rule's declination scale, and the back: calendar
against the solar model, equation of time, shadow-square divisions, unequal-hour circles
and the sine quadrant.

## The instrument in use

[`simulate`](@ref) operates the instrument using only its drawn primitives: it reads the
Sun's longitude from the calendar tick, interpolates its place along the graduated
ecliptic, turns the rete until the point meets a plate line (intersecting circles), and
reads the rule on the limb scale. `verify` compares, over the year:

- sunrise and sunset with ``\cos H_0 = -\tan φ \tan δ``;
- time from the Sun's altitude 20° with the altitude formula;
- star transits with ``H_\odot = α_\star - α_\odot``;

to 0.001 minutes; in practice they agree to about ``10^{-8}`` minutes. The tests also compare
the instrument's sunrise for Zürich in zone time (with the equation of time read from the
back) with an independent solar ephemeris (SolarPosition.jl): they agree within the
Sun's motion between noon, for which the calendar is drawn, and sunrise.

## Fabrication

For the instrument's profile, every part is checked to be one piece, to have no bridge
narrower than the minimum feature (a morphological opening with that diameter must not split it),
holes no smaller than the profile allows, text at least the minimum height and wholly on
the material with the engraving margin, and no overlapping text.

## How accurate is the finished instrument?

[`error_budget`](@ref) perturbs the drawn instrument the way fabrication does: it
displaces the rete by up to the pin clearance, scales it by the profile's tolerance, and
misreads the rule by half a line width. It reports the effect on sunrise times. For a
150 mm laser-cut instrument the 95th percentile is under a minute, far below what an
eye can read on the limb.

Refraction (about 34′ at the horizon, making sunrise a few minutes earlier) is not
drawn on the instrument, as on historical astrolabes; the simulator's sunrise is the
geometric one.
