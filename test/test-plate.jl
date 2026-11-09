@testsnippet PlateHelpers begin
    const PHASE2_LATITUDES = [0, 5, 23.4, 30, 47.3, 51.5, 60, 66, 70, 80, -33.9, -47]
    allpoints(plate) =
        reduce(vcat, [sample_points(p, 100) for el in plate.elements for p in el.prims])
    rr(p) = hypot(p.x, p.y)
end

@testitem "Plates pass the sampling harness at 1e-9 (Phase 2 latitudes)" tags =
    [:plate, :verify] setup = [PlateHelpers] begin
    for φ in PHASE2_LATITUDES
        r = verify(Plate(φ))
        @test Astrolabes.passed(r)
        isempty(Astrolabes.failures(r)) || display(r)
    end
    # finer almucantar step and a historical epoch
    @test Astrolabes.passed(
        verify(Plate(51.75; epoch = Epoch(1391.0), almucantar_step = 1)),
    )
end

@testitem "Plate contents" tags = [:plate] setup = [PlateHelpers] begin
    p = Plate(47.3; almucantar_step = 5)
    kinds = [e.kind for e in p.elements]
    @test count(==(:almucantar), kinds) == 17            # 5°, 10°, …, 85°
    @test count(==(:horizon), kinds) == 1
    @test only(e for e in p.elements if e.kind === :limb).layer === :cut
    @test limb_radius(p) ≈ tand((90 + p.obliquity) / 2)
    @test p.projection.hemisphere === :north
    @test Plate(-10).projection.hemisphere === :south
    @test occursin("47.3", sprint(show, p))
    @test_throws ArgumentError Plate(90)
    @test_throws ArgumentError Plate(45; almucantar_step = 0)
end

@testitem "Everything is clipped to the limb" tags = [:plate] setup = [PlateHelpers] begin
    for φ in PHASE2_LATITUDES
        p = Plate(φ)
        @test all(q -> rr(q) <= limb_radius(p) * (1 + 1e-12), allpoints(p))
    end
end

@testitem "Edge case: equator (φ = 0) horizon is a line through the centre" tags = [:plate] begin
    p = Plate(0.0)
    hor = only(e for e in p.elements if e.kind === :horizon)
    seg = only(hor.prims)
    @test seg isa Segment
    @test abs(seg.a.y) < 1e-15 && abs(seg.b.y) < 1e-15
    @test abs(seg.a.x) ≈ limb_radius(p)
end

@testitem "Edge case: degenerate almucantar becomes a line" tags = [:plate] begin
    # sinφ + sin a = 0  ⇒  the almucantar passes through the projection pole
    P = Stereographic(:north)
    for (φ, a) in ((30.0, -30.0), (47.3, -47.3), (10.0, -10.0))
        l = Astrolabes.almucantar_primitive(φ, a)
        @test l isa Line
        @test l.p.y ≈ -tand(φ)
        rl = 3.0
        prims = clip_to_disk(l, Circle(Pt(0, 0), rl))
        pts = [Astrolabes.project_altaz(P, az, a, φ) for az = 0:1.0:359]
        pts = filter(q -> hypot(q.x, q.y) < rl, pts)
        @test check_curve(prims, pts; tol = 1e-9).passed
    end
end

@testitem "Edge case: arctic plates — the horizon misses the inner tropic" tags = [:plate] begin
    for φ in (66.6, 70.0, 80.0)
        p = Plate(φ)
        hor = only(only(e for e in p.elements if e.kind === :horizon).prims)
        trop = only(only(e for e in p.elements if e.kind === :tropic).prims)
        @test isempty(intersect_prims(hor, trop; tol = 1e-9))
    end
    # below the arctic circle the horizon does cut the Tropic of Cancer
    p = Plate(47.3)
    hor = only(only(e for e in p.elements if e.kind === :horizon).prims)
    trop = only(only(e for e in p.elements if e.kind === :tropic).prims)
    @test length(intersect_prims(hor, trop; tol = 1e-9)) == 2
end

@testitem "Edge case: near-polar latitude is clamped" tags = [:plate] begin
    p = @test_logs (:warn,) Plate(89.9)
    @test p.latitude == 89.5
    # near the pole the sphere conversions lose a few digits: 1e-7° is still exact for fabrication
    @test Astrolabes.passed(verify(p; tol = 1e-7))
    @test (@test_logs (:warn,) Plate(-89.9)).latitude == -89.5
end

@testitem "Property: symmetry about the meridian" tags = [:plate, :property] setup =
    [PlateHelpers] begin
    for φ in (5.0, 47.3, -33.9, 70.0)
        p = Plate(φ)
        prims = reduce(vcat, [el.prims for el in p.elements])
        @test maximum(q -> distance_to(prims, Pt(-q.x, q.y)), allpoints(p)) < 1e-12
    end
end

@testitem "Property: southern plate = mirrored northern plate with φ → −φ" tags =
    [:plate, :property] setup = [PlateHelpers] begin
    for φ in (12.0, 33.9, 47.0)
        n, s = Plate(φ), Plate(-φ)
        @test s.projection.hemisphere === :south
        nprims = reduce(vcat, [el.prims for el in n.elements])
        # mirror every southern point and look for it on the northern plate
        @test maximum(q -> distance_to(nprims, Pt(-q.x, q.y)), allpoints(s)) < 1e-12
    end
end

@testitem "Property: almucantars nest, horizon outermost" tags = [:plate, :property] begin
    for φ in (10.0, 47.3, -33.9, 60.0)
        p = Plate(φ; almucantar_step = 10)
        P = p.projection
        # each almucantar's projected zenith-side meridian point moves monotonically
        # toward the zenith as the altitude increases
        zen = Astrolabes.project_altaz(P, 0.0, 90.0, φ)
        alts = [e.value for e in p.elements if e.kind in (:horizon, :almucantar)]
        @test issorted(alts)
        d = [
            hypot(
                (Astrolabes.project_altaz(P, 180.0, a, φ) - zen).x,
                (Astrolabes.project_altaz(P, 180.0, a, φ) - zen).y,
            ) for a in alts
        ]
        @test issorted(d; rev = true)
        # and the circles are nested: each lies strictly inside the previous one
        circs = [
            only(e.prims) for
            e in p.elements if e.kind === :almucantar && only(e.prims) isa Circle
        ]
        for (c1, c2) in zip(circs, circs[2:end])
            @test hypot((c2.c - c1.c).x, (c2.c - c1.c).y) + c2.r < c1.r
        end
    end
end

@testitem "SVG rendering" tags = [:render] begin
    p = Plate(47.3; almucantar_step = 10)
    path = render_svg(p, tempname() * ".svg"; diameter_mm = 150)
    s = read(path, String)
    @test startswith(s, "<?xml")
    @test occursin("<g id=\"cut\"", s) && occursin("<g id=\"engrave\"", s)
    nprims = sum(length(e.prims) for e in p.elements)
    @test count("<circle", s) +
          count("<path", s) +
          count("<line", s) +
          count("<polyline", s) +
          count("<polygon", s) == nprims
    # the limb (cut layer) is a 150 mm circle
    @test occursin("r=\"75.0000\"", s)
    # φ = 0 plate renders its horizon as a line
    s0 = read(render_svg(Plate(0.0), tempname() * ".svg"), String)
    @test occursin("<line", s0)
end
