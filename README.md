# Astrolabes

[![Stable Documentation](https://img.shields.io/badge/docs-stable-blue.svg)](https://mthelm85.github.io/Astrolabes.jl/stable)
[![Development documentation](https://img.shields.io/badge/docs-dev-blue.svg)](https://mthelm85.github.io/Astrolabes.jl/dev)
[![Test workflow status](https://github.com/mthelm85/Astrolabes.jl/actions/workflows/Test.yml/badge.svg?branch=main)](https://github.com/mthelm85/Astrolabes.jl/actions/workflows/Test.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/mthelm85/Astrolabes.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/mthelm85/Astrolabes.jl)
[![Lint workflow Status](https://github.com/mthelm85/Astrolabes.jl/actions/workflows/Lint.yml/badge.svg?branch=main)](https://github.com/mthelm85/Astrolabes.jl/actions/workflows/Lint.yml?query=branch%3Amain)
[![Docs workflow Status](https://github.com/mthelm85/Astrolabes.jl/actions/workflows/Docs.yml/badge.svg?branch=main)](https://github.com/mthelm85/Astrolabes.jl/actions/workflows/Docs.yml?query=branch%3Amain)
[![BestieTemplate](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/JuliaBesties/BestieTemplate.jl/main/docs/src/assets/badge.json)](https://github.com/JuliaBesties/BestieTemplate.jl)



Geometrically exact, fabrication-ready astrolabes for any latitude and epoch, with built-in verification of every drawn line against spherical astronomy.

```julia
using Astrolabes
plate = Plate(47.3)
verify(plate)
render_svg(plate, "plate.svg"; diameter_mm = 150)
```

