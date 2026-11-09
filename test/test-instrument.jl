@testsnippet Instrument begin
    const A47 = astrolabe(47.3; longitude = 8.54, timezone = 1.0)
    function dxf_entities(path)
        lines = strip.(readlines(path))
        pairs = [(lines[i], lines[i+1]) for i = 1:2:(length(lines)-1)]
        ents = Vector{Dict{String,Any}}()
        cur = nothing
        for (code, val) in pairs
            if code == "0"
                cur = Dict{String,Any}("type" => val, "xs" => Float64[], "ys" => Float64[])
                push!(ents, cur)
            elseif cur !== nothing
                if code == "8"
                    cur["layer"] = val
                elseif code == "10"
                    push!(cur["xs"], parse(Float64, val))
                elseif code == "20"
                    push!(cur["ys"], parse(Float64, val))
                elseif code == "40"
                    cur["r"] = parse(Float64, val)
                end
            end
        end
        return ents
    end
end

@testitem "Star catalogue" tags = [:catalog] begin
    cat = Astrolabes.star_catalog()
    @test length(cat) == 59
    @test all(c -> 0 <= c.star.ra < 360 && -90 <= c.star.dec <= 90, cat)
    s = find_star("Sirius")
    @test s.vmag ≈ -1.44 atol = 0.05
    @test abs(s.dec - (-16.716)) < 0.01
    @test traditional_name("Aldebaran") != ""
    @test length(catalog_stars(:default)) < length(catalog_stars(:all))
    @test [x.name for x in catalog_stars(["Vega", "Deneb"])] == ["Vega", "Deneb"]
    @test_throws ArgumentError find_star("Not A Star")
end

@testitem "Complete instrument passes verification" tags = [:instrument, :verify] setup =
    [Instrument] begin
    r = verify(A47)
    @test Astrolabes.passed(r)
    isempty(Astrolabes.failures(r)) || display(r)
    for a in (
        astrolabe(-33.9),
        astrolabe(51.75; epoch = 1391.0, calendar = :eccentric),
        astrolabe(51.5; profile = Metal()),
        astrolabe(35.0; diameter_mm = 100),
    )
        local rep = verify(a)
        @test Astrolabes.passed(rep)
        isempty(Astrolabes.failures(rep)) || display(rep)
    end
end

@testitem "Instrument contents" tags = [:instrument] setup = [Instrument] begin
    a = A47
    @test a.epoch.calendar === :gregorian
    @test astrolabe(51.75; epoch = 1391.0).epoch.calendar === :julian
    @test length(a.rete.pointers) >= 20
    @test any(p -> p.labelled, a.rete.pointers)
    @test all(p -> p.kind in (:pointer, :marker, :notch), a.rete.pointers)
    ps = parts(a)
    @test [p.name for p in ps] == ["mater", "limb", "plate_47p3N", "rete", "rule", "alidade", "vane"]
    @test only(p for p in ps if p.name == "vane").quantity == 2
    @test only(p for p in ps if p.name == "mater").face === :back
    multi = astrolabe(47.3; latitudes = (46.0, 48.5))
    @test count(p -> startswith(p.name, "plate_"), parts(multi)) == 3
    @test only(p for p in parts(multi) if p.name == "limb_spacer").quantity == 2
    @test_throws ArgumentError astrolabe(47.3; latitudes = (-10.0,))
    @test_throws ArgumentError astrolabe(47.3; longitude = 8.5)
    @test_throws ArgumentError astrolabe(47.3; diameter_mm = 40)
    @test astrolabe("47°18′N").plates[1].latitude ≈ 47.3
    @test occursin("47.3", sprint(show, a))
end

@testitem "Simulator agrees with closed-form astronomy" tags = [:simulate] setup =
    [Instrument] begin
    sim = simulate(A47)
    φ = 47.3
    ε = A47.rete.obliquity
    for (m, d) in ((3, 20), (6, 21), (9, 23), (12, 21), (2, 10))
        λ = calendar_longitude(sim, (m, d))
        δ = asind(sind(ε) * sind(λ))
        H0 = acosd(-tand(φ) * tand(δ)) / 15
        @test sunrise(sim, (m, d)).apparent ≈ 12 - H0 atol = 1e-6
        @test sunset(sim, (m, d)).apparent ≈ 12 + H0 atol = 1e-6
    end
    # no sunrise in the polar night
    @test sunrise(simulate(astrolabe(70.0)), (12, 21)) === nothing
    # a star transit: the Sun's hour angle is then α* − α☉
    λ = calendar_longitude(sim, (1, 1))
    αs = mod(atand(sind(λ) * cosd(ε), cosd(λ)), 360)
    q = precess_to(find_star("Sirius"), A47.epoch)
    @test star_transit(sim, "Sirius", (1, 1)).apparent ≈ mod(12 + (q.ra - αs) / 15, 24) atol =
        1e-6
    @test_throws ArgumentError star_rise(sim, "Polaris", (1, 1))
    @test 50 < sunrise_azimuth(sim, (6, 21)) < 60
end

@testitem "Simulator against an independent solar ephemeris" tags = [:simulate, :oracle] setup =
    [Instrument] begin
    using SolarPosition, Dates
    # Zürich: the instrument's sunrise, read in zone time (CET) with the equation of time
    # from its back, against SolarPosition.jl's geometric sunrise (no refraction)
    obs = Observer(47.3, 8.54, 400.0)
    elev(t) = solar_position(obs, t, SPA()).elevation
    sim = simulate(A47)
    for (m, d) in ((1, 15), (3, 20), (5, 1), (6, 21), (8, 10), (10, 1), (12, 21))
        t = sunrise(sim, (m, d)).mean - 1.0                    # UT, hours
        # bisect for the geometric sunrise
        lo = DateTime(2026, m, d, 3)
        hi = DateTime(2026, m, d, 10)
        for _ = 1:40
            mid = lo + (hi - lo) ÷ 2
            elev(mid) < 0 ? (lo = mid) : (hi = mid)
        end
        truth = hour(lo) + minute(lo) / 60 + (second(lo) + millisecond(lo) / 1000) / 3600
        # the instrument reads the Sun's place at noon, so allow its daily motion
        @test abs(t - truth) * 60 < 2.0
    end
end

@testitem "Fabrication error budget" tags = [:simulate] setup = [Instrument] begin
    eb = error_budget(A47; n = 16)
    @test 0 <= eb.median <= eb.p95 <= eb.max
    @test eb.p95 < 2.0                    # minutes, for a laser-cut 150 mm instrument
end

@testitem "Rendering: LaserCut SVG and DXF" tags = [:render] setup = [Instrument] begin
    dir = mktempdir()
    files = render(A47, dir)
    @test all(isfile, files)
    for p in parts(A47)
        @test isfile(joinpath(dir, p.name * ".svg"))
        @test isfile(joinpath(dir, p.name * ".dxf"))
    end
    @test occursin("Assembly", read(joinpath(dir, "parts.txt"), String))
    svg = read(joinpath(dir, "plate_47p3N.svg"), String)
    @test occursin("<g id=\"CUT\"", svg) && occursin("<g id=\"ENGRAVE\"", svg)
    @test occursin("width=\"", svg) && occursin("mm\"", svg)
    preview = render_preview(A47, joinpath(dir, "preview.svg"))
    @test isfile(preview)
    both = read(preview, String)
    @test occursin("<g id=\"rete\"", both) && occursin("<g id=\"back\"", both)
    front = read(render_preview(A47, joinpath(dir, "f.svg"); side = :front), String)
    @test occursin("<g id=\"rete\"", front) && !occursin("<g id=\"back\"", front)
    back = read(render_preview(A47, joinpath(dir, "b.svg"); side = :back), String)
    @test occursin("<g id=\"alidade\"", back) && !occursin("<g id=\"rete\"", back)
    @test_throws ArgumentError render_preview(A47, joinpath(dir, "x.svg"); side = :top)
end

@testitem "Golden geometry read back from the DXF" tags = [:render, :verify] setup =
    [Instrument] begin
    dir = mktempdir()
    render(A47, dir; formats = (:dxf,))
    ents = dxf_entities(joinpath(dir, "plate_47p3N.dxf"))
    s = A47.scale
    P = A47.projection
    ε = A47.rete.obliquity
    circles = [e for e in ents if e["type"] == "CIRCLE" && e["layer"] == "ENGRAVE"]
    radii = [e["r"] for e in circles if hypot(e["xs"][1], e["ys"][1]) < 1e-6]
    # equator (R = 1) and tropic of Cancer, independently of the plate code
    @test any(r -> abs(r - s) < 1e-5, radii)
    @test any(r -> abs(r - s * tand((90 - ε) / 2)) < 1e-5, radii)
    # every engraved vertex lies on a drawn plate line or label stroke (nothing extra)
    plate = only(p for p in parts(A47) if startswith(p.name, "plate_"))
    ref = Primitive[
        [scale(q, s) for q in plate.engrave]
        [scale(q, s) for l in plate.labels for q in Astrolabes.label_strokes(l)]
    ]
    verts = [
        Pt(x, y) for e in ents if e["type"] == "VERTEX" && e["layer"] == "ENGRAVE" for
        (x, y) in zip(e["xs"], e["ys"])
    ]
    @test length(verts) > 1000
    @test maximum(v -> distance_to(ref, v), verts[1:7:end]) < 1e-5
    # the cut outline is the plate disk
    cut = [
        Pt(x, y) for e in ents if e["type"] == "VERTEX" && e["layer"] == "CUT" for
        (x, y) in zip(e["xs"], e["ys"])
    ]
    rmax = maximum(v -> hypot(v.x, v.y), cut)
    @test rmax ≈ A47.mater.plate_radius * s rtol = 1e-4
end

@testitem "Rendering: Metal, PCB and Paper profiles" tags = [:render] begin
    for (prof, expect) in (
        (Metal(), ["rete_cut.dxf", "rete_engrave.dxf", "rete_cut.svg"]),
        (PCB(), ["rete-Edge_Cuts.dxf", "rete-F_Cu.dxf", "rete-F_SilkS.dxf"]),
        (Paper(), ["rete.svg", "mater.svg"]),
    )
        a = astrolabe(40.0; profile = prof)
        dir = mktempdir()
        render(a, dir)
        for f in expect
            @test isfile(joinpath(dir, f))
        end
        if prof isa Paper
            @test !isfile(joinpath(dir, "rete.dxf"))
            @test occursin("calibration", read(joinpath(dir, "rete.svg"), String))
        end
    end
end
