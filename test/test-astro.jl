@testsnippet AstroHelpers begin
    const SOFA = Astrolabes.SOFA
    # angular separation in arcseconds (haversine: accurate for tiny angles)
    sep(a1, d1, a2, d2) =
        2 *
        asind(sqrt(sind((d2 - d1) / 2)^2 + cosd(d1) * cosd(d2) * sind((a2 - a1) / 2)^2)) *
        3600
    const NAMED = [
        Star("Regulus", 152.09296, 11.96721),
        Star("Arcturus", 213.91530, 19.18241),
        Star("Vega", 279.23473, 38.78369),
        Star("Sirius", 101.28716, -16.71612),
        Star("Polaris", 37.95456, 89.26411),
    ]
end

@testitem "Calendar → Julian Day" tags = [:astro] setup = [AstroHelpers] begin
    # Gregorian: agree with SOFA's cal2jd
    for (y, m, d) in
        ((2000, 1, 1), (1992, 10, 13), (1600, 2, 29), (1858, 11, 17), (2026, 11, 9))
        r = SOFA.cal2jd(y, m, d)
        @test calendar_to_jd(y, m, d) == r.mjd0 + r.mjd
    end
    # Meeus, Astronomical Algorithms, examples 7.a and 7.b
    @test calendar_to_jd(1957, 10, 4.81) ≈ 2436116.31
    @test calendar_to_jd(333, 1, 27.5; calendar = :julian) == 1842713.0
    # the Gregorian reform: 1582 Oct 4 (Julian) is followed by Oct 15 (Gregorian)
    @test calendar_to_jd(1582, 10, 15) - calendar_to_jd(1582, 10, 4; calendar = :julian) ==
          1
    @test_throws ArgumentError calendar_to_jd(2000, 1, 1; calendar = :lunar)
    @test_throws ArgumentError calendar_to_jd(2000, 13, 1)
end

@testitem "Epoch" tags = [:astro] begin
    @test julian_day(Epoch(2000.0)) == 2451545.0
    @test Epoch(2000, 1, 1.5).year ≈ 2000.0 atol = 1e-12
    e = Epoch(1391, 3, 12; calendar = :julian)
    @test e.calendar === :julian
    @test julian_day(e) ≈ calendar_to_jd(1391, 3, 12; calendar = :julian)
    @test_throws ArgumentError Epoch(2000.0; calendar = :mayan)
end

@testitem "Long-term precession wiring (SOFA t_ltp reference)" tags = [:astro] begin
    # Reference matrix from SOFA's own test suite (t_sofa_c.c, t_ltp)
    ref = [
        0.9967044141159213819 0.743780189319321084e-1 0.3237624409345603401e-1;
        -0.7437802731819618167e-1 0.997229389445453307 -0.1205768842723593346e-2;
        -0.3237622482766575399e-1 -0.1206286039697609008e-2 0.9994750246704010914
    ]
    @test maximum(abs.(Astrolabes.precession_matrix(Epoch(1666.666)) .- ref)) < 1e-14
end

@testitem "Precession of named stars vs AstroLib (independent oracle)" tags =
    [:astro, :oracle] setup = [AstroHelpers] begin
    using AstroLib: precess
    # AstroLib uses the IAU 1976 (FK5) precession; ours is Vondrák et al. (2011) in the
    # GCRS. They differ by ~0.1″ today and ~2″ a millennium ago.
    for s in NAMED, (y, tol) in ((2050.0, 0.5), (1500.0, 2.5), (1391.0, 2.5), (1000.0, 3.0))
        p = precess_to(s, Epoch(y))
        ra2, dec2 = precess(s.ra, s.dec, 2000.0, y)
        @test sep(p.ra, p.dec, ra2, dec2) < tol
    end
    # identity at J2000 (up to the frame being the same)
    p = precess_to(NAMED[1], Epoch(2000.0))
    @test sep(p.ra, p.dec, NAMED[1].ra, NAMED[1].dec) < 1e-3
end

@testitem "Proper motion" tags = [:astro] setup = [AstroHelpers] begin
    # Arcturus: large proper motion (Hipparcos 2007: μα* = −1093.39, μδ = −2000.06 mas/yr)
    arc = Star(
        "Arcturus",
        213.91530,
        19.18241;
        pmra = -1093.39,
        pmdec = -2000.06,
        parallax = 88.83,
        rv = -5.19,
    )
    still = precess_to(arc, Epoch(1000.0); proper_motion = false)
    moved = precess_to(arc, Epoch(1000.0))
    # ~1000 years × ~2.28″/yr ≈ 38′ of space motion
    @test 2200 < sep(still.ra, still.dec, moved.ra, moved.dec) < 2400
    # linear model agrees to first order over a short span
    s50 = precess_to(arc, Epoch(2050.0))
    dδ = -2000.06e-3 * 50 / 3600
    lin = precess_to(
        Star("x", arc.ra + (-1093.39e-3 * 50 / 3600) / cosd(arc.dec), arc.dec + dδ),
        Epoch(2050.0),
    )
    @test sep(s50.ra, s50.dec, lin.ra, lin.dec) < 0.05
end

@testitem "Obliquity" tags = [:astro] setup = [AstroHelpers] begin
    for y = 1800.0:25.0:2200.0
        ε06 = rad2deg(SOFA.obl06(julian_day(Epoch(y)), 0.0))
        @test abs(obliquity(Epoch(y)) - ε06) * 3600 < 1.0
    end
    @test obliquity(2000.0) ≈ 84381.406 / 3600 atol = 1e-6   # IAU 2006 value at J2000
    # long-term behaviour: larger in the past (≈ 23.52° in 1391)
    @test 23.51 < obliquity(Epoch(1391.0)) < 23.53
end

@testitem "Sun: Meeus example 25.a" tags = [:astro] begin
    s = sun_position(calendar_to_jd(1992, 10, 13.0))
    @test s.mean_longitude ≈ 201.80720 atol = 1e-5
    @test s.mean_anomaly ≈ 278.99397 atol = 1e-5
    @test s.distance ≈ 0.99766 atol = 1e-5
    @test s.longitude ≈ 199.90895 atol = 2e-5
    @test s.ra ≈ 198.38083 atol = 2e-5
    @test s.dec ≈ -7.78507 atol = 2e-5
    @test s.obliquity ≈ 23.43999 atol = 1e-5
    @test sun_position(Epoch(1992, 10, 13.0)).dec ≈ s.dec
end

@testitem "Equation of time: Meeus example 28" tags = [:astro] begin
    # 1992 Oct 13.0 TD: E = +13m 42.6s; our low-precision model is within ~1 s
    E = equation_of_time(calendar_to_jd(1992, 10, 13.0))
    @test abs(E * 60 - (13 * 60 + 42.6)) < 2.0
    @test equation_of_time(Epoch(1992, 10, 13.0)) ≈ E
end

@testitem "Sun vs SolarPosition.jl SPA, 2000–2050" tags = [:astro, :oracle] begin
    using SolarPosition: Observer, SPA, solar_position
    using Dates
    obs = Observer(47.3, 0.0, 0.0)          # longitude 0 so mean time = UT
    dδ = Float64[]
    dE = Float64[]
    for day = 0:37:(50*365)
        t = DateTime(2000, 1, 1, 12) + Day(day)
        sp = solar_position(obs, t, SPA())
        h = hadec(sp.azimuth, sp.elevation, 47.3)  # geometric elevation, no refraction
        jd = datetime2julian(t)                     # UT; TT−UT (~1 min) is negligible here
        s = sun_position(jd)
        E_spa = 4 * h.H                             # minutes: apparent − mean solar time at 12h UT
        push!(dδ, abs(s.dec - h.dec))
        push!(dE, abs(equation_of_time(jd) - E_spa) * 60)
    end
    @test length(dδ) > 490
    @test maximum(dδ) < 0.02      # degrees
    @test maximum(dE) < 5.0       # seconds
end

@testitem "Horizon ↔ equatorial" tags = [:astro] begin
    for φ in (-60.0, 0.0, 47.3), az = 0.0:30.0:330.0, alt in (-10.0, 0.0, 45.0)
        h = hadec(az, alt, φ)
        b = altaz(h.H, h.dec, φ)
        @test b.alt ≈ alt atol = 1e-10
        @test mod(b.az - az + 180, 360) - 180 ≈ 0 atol = 1e-9
    end
    # transit: a star on the meridian at δ culminates at 90° − |φ − δ|
    @test altaz(0.0, 20.0, 47.3).alt ≈ 90 - 27.3
end

@testitem "Latitude parsing (AstroAngles)" tags = [:astro] begin
    @test parse_latitude("47°18′N") ≈ 47.3
    @test parse_latitude("33d52m S") ≈ -(33 + 52 / 60)
    @test parse_latitude("-33:52") ≈ -(33 + 52 / 60)
    @test parse_latitude("51.75") == 51.75
    @test Plate("51°45′N").latitude ≈ 51.75
    @test_throws ArgumentError parse_latitude("95")
end
