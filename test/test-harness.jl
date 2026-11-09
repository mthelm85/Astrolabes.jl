@testitem "Sampling harness accepts the right curve" tags = [:harness] begin
    # the Tropic of Cancer at ε = 23.44° projects to a circle of radius tan(33.28°)
    P = Stereographic(:north)
    pts = [project(P, H, 23.44) for H = 0:1.0:359]
    c = check_curve(
        Circle(Pt(0, 0), tand((90 - 23.44) / 2)),
        pts;
        tol = 1e-12,
        label = "tropic",
    )
    @test c.passed
    @test c.n == 360
    @test c.max_err < 1e-14
    @test check_point(Pt(1, 2), Pt(1, 2 + 1e-13); tol = 1e-12).passed
end

@testitem "Sampling harness catches a wrong circle" tags = [:harness] begin
    P = Stereographic(:north)
    φ, a = 47.3, 20.0
    pts = [Astrolabes.project_altaz(P, az, a, φ) for az = 0:2.0:358]
    right = Astrolabes.almucantar_primitive(φ, a)
    @test check_curve(right, pts; tol = 1e-9).passed
    # 1e-6 shift of the centre, 1e-6 error in the radius, and a classic sign slip
    wrong_centre = Circle(right.c + Pt(0, 1e-6), right.r)
    wrong_radius = Circle(right.c, right.r * (1 + 1e-6))
    sign_slip = Circle(Pt(0, cosd(φ) / (sind(φ) - sind(a))), cosd(a) / (sind(φ) - sind(a)))
    for w in (wrong_centre, wrong_radius, sign_slip)
        c = check_curve(w, pts; tol = 1e-9)
        @test !c.passed
        @test c.max_err > 1e-7
    end
    # a check with no samples is never a pass
    @test !check_curve(right, Pt[]; tol = 1e-9).passed
    @test occursin("FAIL", sprint(show, check_curve(sign_slip, pts; tol = 1e-9)))
end

@testitem "Backward check catches extra (unclipped) geometry" tags = [:harness] begin
    P = Stereographic(:north)
    φ = 47.3
    rl = tand((90 + 23.44) / 2)
    hor = Astrolabes.almucantar_primitive(φ, 0.0)
    clipped = clip_to_disk(hor, Circle(Pt(0, 0), rl))
    resid(p) =
        (h = unproject(P, p); abs(altaz(h.H, h.dec, φ).alt) + max(hypot(p.x, p.y) - rl, 0))
    @test Astrolabes.check_definition(clipped, resid; tol = 1e-9).passed
    # forgetting to clip draws horizon outside the limb: forward samples still pass,
    # but the backward check fails
    @test !Astrolabes.check_definition([hor], resid; tol = 1e-9).passed
    # and a wrong curve fails the backward check too
    @test !Astrolabes.check_definition([Circle(hor.c, hor.r * 1.001)], resid; tol = 1e-9).passed
end
