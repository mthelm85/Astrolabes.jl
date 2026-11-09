@testitem "Intersections" tags = [:geometry] begin
    # circle–circle: unit circles 1 apart meet at (0.5, ±√3/2)
    pts = intersect_prims(Circle(Pt(0, 0), 1.0), Circle(Pt(1, 0), 1.0))
    @test length(pts) == 2
    @test all(p -> isapprox(p.x, 0.5) && isapprox(abs(p.y), sqrt(3) / 2), pts)
    # tangent and disjoint
    @test length(intersect_prims(Circle(Pt(0, 0), 1.0), Circle(Pt(2, 0), 1.0))) == 1
    @test isempty(intersect_prims(Circle(Pt(0, 0), 1.0), Circle(Pt(3, 0), 1.0)))
    @test isempty(intersect_prims(Circle(Pt(0, 0), 1.0), Circle(Pt(0, 0), 0.5)))
    # circle–line
    pts = intersect_prims(Circle(Pt(0, 0), 2.0), Line(Pt(0, 1), Pt(1, 0)))
    @test sort([p.x for p in pts]) ≈ [-sqrt(3), sqrt(3)]
    @test isempty(intersect_prims(Line(Pt(0, 3), Pt(1, 0)), Circle(Pt(0, 0), 2.0)))
    # line–line, parallel lines
    @test only(intersect_prims(Line(Pt(0, 0), Pt(1, 1)), Line(Pt(2, 0), Pt(0, 1)))) ≈
          Pt(2, 2)
    @test isempty(intersect_prims(Line(Pt(0, 0), Pt(1, 0)), Line(Pt(0, 1), Pt(1, 0))))
    # arcs and segments filter their carriers
    upper = Arc(Pt(0, 0), 1.0, 0.0, π)
    @test length(intersect_prims(upper, Line(Pt(0, 0), Pt(1, 0)))) == 2   # endpoints
    @test length(intersect_prims(upper, Line(Pt(0, -0.5), Pt(1, 0)))) == 0
    @test length(intersect_prims(Segment(Pt(-3, 0), Pt(0, 0)), Circle(Pt(0, 0), 1.0))) == 1
end

@testitem "Distances" tags = [:geometry] begin
    a = Arc(Pt(0, 0), 1.0, 0.0, π / 2)
    @test distance_to(a, Pt(2, 0)) ≈ 1.0
    @test distance_to(a, Pt(0, -1)) ≈ sqrt(2)       # nearest is the endpoint (1, 0)
    @test distance_to(Line(Pt(0, 1), Pt(3, 0)), Pt(5, 4)) ≈ 3
    @test distance_to(Segment(Pt(0, 0), Pt(1, 0)), Pt(2, 0)) ≈ 1
    @test distance_to(Polyline([Pt(0, 0), Pt(1, 0), Pt(1, 1)]), Pt(2, 1)) ≈ 1
    @test distance_to(Polyline([Pt(0, 0), Pt(1, 0), Pt(1, 1)], true), Pt(0.4, 0.6)) ≈
          sqrt(2) * 0.1 atol = 1e-12
    @test_throws ArgumentError Arc(Pt(0, 0), 1.0, 1.0, 0.0)
    @test_throws ArgumentError sample_points(Line(Pt(0, 0), Pt(1, 0)), 10)
end

@testitem "Clipping to a disk" tags = [:geometry] begin
    D = Circle(Pt(0, 0), 1.0)
    inD(p) = hypot(p.x, p.y) <= 1 + 1e-12
    @test clip_to_disk(Circle(Pt(0.1, 0), 0.5), D) == [Circle(Pt(0.1, 0), 0.5)]
    @test isempty(clip_to_disk(Circle(Pt(3, 0), 0.5), D))
    @test isempty(clip_to_disk(Circle(Pt(0, 0), 2.0), D))     # encloses the disk
    # a crossing circle leaves one arc whose ends lie on D and whose samples lie inside
    arcs = clip_to_disk(Circle(Pt(1, 0), 1.0), D)
    @test length(arcs) == 1
    a = only(arcs)
    @test all(inD, sample_points(a, 50))
    @test hypot(Astrolabes.arc_point(a, a.θ1).x, Astrolabes.arc_point(a, a.θ1).y) ≈ 1
    @test a.θ2 - a.θ1 ≈ 2π / 3                    # 120° of the unit circle at (1,0) is inside
    # crossing at the angular seam θ = 0 is merged into one arc
    seam = only(clip_to_disk(Circle(Pt(-1, 0), 1.0), D))
    @test seam.θ2 - seam.θ1 ≈ 2π / 3
    @test all(inD, sample_points(seam, 50))
    # line → chord, segment → partial, polyline → pieces
    s = only(clip_to_disk(Line(Pt(0, 0.6), Pt(1, 0)), D))
    @test hypot((s.b - s.a).x, (s.b - s.a).y) ≈ 1.6
    s2 = only(clip_to_disk(Segment(Pt(0, 0), Pt(3, 0)), D))
    @test s2.a ≈ Pt(0, 0) && s2.b ≈ Pt(1, 0)
    @test isempty(clip_to_disk(Line(Pt(0, 2), Pt(1, 0)), D))
    pl = clip_to_disk(Polyline([Pt(-2, 0), Pt(0, 0), Pt(0, 0.5), Pt(2, 0.5)]), D)
    @test length(pl) == 1 && all(inD, only(pl).pts)
    # an arc that starts inside, leaves and re-enters yields two pieces
    pieces = clip_to_disk(Arc(Pt(0, 0.9), 0.5, -π / 2, 3π / 2 - 0.1), D)
    @test length(pieces) == 2
    @test all(inD, reduce(vcat, sample_points.(pieces, 20)))
end

@testitem "Stereographic projection" tags = [:geometry] begin
    N, S = Stereographic(:north), Stereographic(:south)
    for δ = -60.0:15.0:85.0, H = -170.0:20.0:170.0
        p = project(N, H, δ)
        @test hypot(p.x, p.y) ≈ tand((90 - δ) / 2)
        q = unproject(N, p)
        @test q.dec ≈ δ atol = 1e-10
        @test q.H ≈ H atol = 1e-9
        # southern projection = mirror image of the northern projection of the reflected sky
        @test project(S, H, -δ) ≈ Pt(-p.x, p.y)
        r = unproject(S, project(S, H, -δ))
        @test r.dec ≈ -δ atol = 1e-10
        @test r.H ≈ H atol = 1e-9
    end
    # meridian along +y; west (H > 0) to the right on a northern plate
    @test project(N, 0.0, 0.0) ≈ Pt(0, 1)
    @test project(N, 90.0, 0.0).x > 0
    @test project(S, 90.0, 0.0).x < 0
    # the zenith of latitude φ lies on +y at R tan((90° − φ)/2)
    @test Astrolabes.project_altaz(N, 0.0, 90.0, 47.3) ≈ Pt(0, tand((90 - 47.3) / 2))
    @test Stereographic(:north; R = 2).R == 2
    @test_throws ArgumentError Stereographic(:east)
end
