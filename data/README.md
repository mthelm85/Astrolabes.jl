# Star data

`stars.csv` lists the 59 bright stars that the rete may carry.

| Column | Meaning |
|---|---|
| `hip` | Hipparcos catalogue number |
| `name` | IAU-approved proper name (WGSN) |
| `bayer` | Bayer designation |
| `traditional` | a historical (mostly Arabic) name as used on medieval astrolabes |
| `ra`, `dec` | ICRS position at epoch J2000.0, degrees |
| `pmra`, `pmdec` | proper motion, mas/yr (`pmra` includes cos δ) |
| `parallax` | mas |
| `vmag` | Johnson V magnitude |
| `default` | `true` for the stars placed on the rete by default |

## Sources

- Astrometry: *Hipparcos, the New Reduction of the Raw Data*, van Leeuwen (2007),
  VizieR catalogue I/311.
- Magnitudes: *The Hipparcos and Tycho Catalogues*, ESA (1997), VizieR catalogue I/239.

The positions were moved from the catalogue epoch J1991.25 to J2000.0 with SOFA `pmsafe`.
`scripts/build_star_catalog.jl` regenerates the file.

This research has made use of the VizieR catalogue access tool, CDS, Strasbourg, France
(DOI 10.26093/cds/vizier). The data are used under the CDS terms of use, which allow
redistribution with this acknowledgement.

The `traditional` names are given as one common historical form among several; spellings
and attributions vary between sources and instruments.
