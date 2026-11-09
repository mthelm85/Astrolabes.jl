# [Gallery](@id gallery)

Each instrument is shown front (left: plate, rete and rule) and back (right: the mater's
altitude scale, zodiac, calendar, equation of time, shadow square and unequal hours, with
the alidade). Each passed `verify` (geometry, use and fabrication checks) before its
preview was drawn. Rebuild them with `julia --project=. examples/gallery.jl`.

## Zürich (47.3°N), hour scale in CET

```julia
astrolabe(47.3; longitude = 8.54, timezone = 1.0)
```

```@raw html
<img src="../assets/gallery/zurich.svg" alt="Zürich">
```

## London (51.5°N), brass

```julia
astrolabe(51.5; profile = Metal())
```

```@raw html
<img src="../assets/gallery/london.svg" alt="London">
```

## Oxford 1391 (51.75°N), after Chaucer's *Treatise on the Astrolabe*

```julia
astrolabe(51.75; epoch = 1391.0, calendar = :eccentric, names = :traditional)
```

```@raw html
<img src="../assets/gallery/chaucer.svg" alt="Oxford 1391">
```

## Sydney (33.9°S)

```julia
astrolabe(-33.9)
```

```@raw html
<img src="../assets/gallery/sydney.svg" alt="Sydney">
```

## The equator, the tropic and the Arctic Circle

```julia
astrolabe(0.0); astrolabe(23.4); astrolabe(66.0)
```

```@raw html
<img src="../assets/gallery/equator.svg" alt="Equator">
```
```@raw html
<img src="../assets/gallery/tropic.svg" alt="Tropic of Cancer">
```
```@raw html
<img src="../assets/gallery/arctic.svg" alt="Arctic Circle">
```
