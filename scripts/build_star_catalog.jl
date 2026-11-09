# Build data/stars.csv from the Hipparcos catalogue (run manually, needs network).
#
#     julia --project=. scripts/build_star_catalog.jl
#
# Astrometry: Hipparcos, the New Reduction (van Leeuwen 2007; VizieR I/311/hip2),
# epoch J1991.25, propagated to J2000.0 with SOFA's pmsafe. V magnitudes: the original
# Hipparcos main catalogue (ESA 1997; VizieR I/239/hip_main).
#
# The queries use VizieR's ASU interface. CDS's own TAP service (used by
# VirtualObservatory.jl) is not reachable from every network, so the script tries the
# VizieR mirrors in turn.

using Downloads
using Printf
using Astrolabes: Astrolabes
const SOFA = Astrolabes.SOFA

const MIRRORS = [
    "https://vizier.cfa.harvard.edu",
    "https://vizier.cds.unistra.fr",
    "https://vizier.iucaa.in",
]

# IAU name, HIP, Bayer designation, traditional (Arabic-derived) name, approximate
# RA (hours) and Dec (degrees) used only to catch a wrong HIP number, default flag.
const STARS = [
    ("Alpheratz", 677, "α And", "Surrat al-Faras", 0.14, 29.1, true),
    ("Caph", 746, "β Cas", "al-Kaff al-Khaḍīb", 0.15, 59.1, false),
    ("Algenib", 1067, "γ Peg", "al-Janāḥ", 0.22, 15.2, false),
    ("Schedar", 3179, "α Cas", "al-Ṣadr", 0.68, 56.5, true),
    ("Diphda", 3419, "β Cet", "al-Ḍifdiʿ al-Thānī", 0.73, -18.0, true),
    ("Mirach", 5447, "β And", "al-Mirāq", 1.16, 35.6, true),
    ("Achernar", 7588, "α Eri", "Ākhir al-Nahr", 1.63, -57.2, true),
    ("Hamal", 9884, "α Ari", "Raʾs al-Ḥamal", 2.12, 23.5, true),
    ("Polaris", 11767, "α UMi", "al-Jady", 2.53, 89.3, true),
    ("Menkar", 14135, "α Cet", "Minkhar al-Qayṭus", 3.04, 4.1, true),
    ("Algol", 14576, "β Per", "Raʾs al-Ghūl", 3.14, 41.0, true),
    ("Mirfak", 15863, "α Per", "Mirfaq al-Thurayyā", 3.41, 49.9, true),
    ("Alcyone", 17702, "η Tau", "al-Thurayyā", 3.79, 24.1, true),
    ("Aldebaran", 21421, "α Tau", "al-Dabarān", 4.60, 16.5, true),
    ("Rigel", 24436, "β Ori", "Rijl al-Jawzāʾ", 5.24, -8.2, true),
    ("Capella", 24608, "α Aur", "al-ʿAyyūq", 5.28, 46.0, true),
    ("Bellatrix", 25336, "γ Ori", "al-Murzim", 5.42, 6.35, true),
    ("Elnath", 25428, "β Tau", "al-Naṭḥ", 5.44, 28.6, false),
    ("Alnilam", 26311, "ε Ori", "al-Niẓām", 5.60, -1.2, false),
    ("Betelgeuse", 27989, "α Ori", "Yad al-Jawzāʾ", 5.92, 7.4, true),
    ("Menkalinan", 28360, "β Aur", "Mankib Dhī al-ʿInān", 6.00, 44.9, false),
    ("Canopus", 30438, "α Car", "Suhayl", 6.40, -52.7, true),
    ("Alhena", 31681, "γ Gem", "al-Hanʿa", 6.63, 16.4, false),
    ("Sirius", 32349, "α CMa", "al-Shiʿrā al-Yamāniya", 6.75, -16.7, true),
    ("Adhara", 33579, "ε CMa", "al-ʿAdhārā", 6.98, -29.0, false),
    ("Castor", 36850, "α Gem", "Raʾs al-Tawʾam al-Muqaddam", 7.58, 31.9, true),
    ("Procyon", 37279, "α CMi", "al-Shiʿrā al-Shāmiya", 7.66, 5.2, true),
    ("Pollux", 37826, "β Gem", "Raʾs al-Tawʾam al-Muʾakhkhar", 7.76, 28.0, true),
    ("Alphard", 46390, "α Hya", "al-Fard", 9.46, -8.7, true),
    ("Regulus", 49669, "α Leo", "Qalb al-Asad", 10.14, 12.0, true),
    ("Dubhe", 54061, "α UMa", "al-Dubb", 11.06, 61.8, true),
    ("Denebola", 57632, "β Leo", "Dhanab al-Asad", 11.82, 14.6, true),
    ("Gienah", 59803, "γ Crv", "al-Janāḥ", 12.26, -17.5, false),
    ("Acrux", 60718, "α Cru", "", 12.44, -63.1, true),
    ("Alioth", 62956, "ε UMa", "", 12.90, 56.0, true),
    ("Vindemiatrix", 63608, "ε Vir", "", 13.04, 11.0, false),
    ("Spica", 65474, "α Vir", "al-Simāk al-Aʿzal", 13.42, -11.2, true),
    ("Alkaid", 67301, "η UMa", "al-Qāʾid", 13.79, 49.3, true),
    ("Hadar", 68702, "β Cen", "", 14.06, -60.4, true),
    ("Arcturus", 69673, "α Boo", "al-Simāk al-Rāmiḥ", 14.26, 19.2, true),
    ("Rigil Kentaurus", 71683, "α Cen", "Rijl Qanṭūris", 14.66, -60.8, true),
    ("Kochab", 72607, "β UMi", "al-Kawkab", 14.85, 74.2, true),
    ("Zubenelgenubi", 72622, "α Lib", "al-Zubānā al-Janūbiyya", 14.85, -16.0, true),
    ("Alphecca", 76267, "α CrB", "Nayyir al-Fakka", 15.58, 26.7, true),
    ("Unukalhai", 77070, "α Ser", "ʿUnuq al-Ḥayya", 15.74, 6.4, false),
    ("Antares", 80763, "α Sco", "Qalb al-ʿAqrab", 16.49, -26.4, true),
    ("Shaula", 85927, "λ Sco", "al-Shawla", 17.56, -37.1, false),
    ("Rasalhague", 86032, "α Oph", "Raʾs al-Ḥawwāʾ", 17.58, 12.6, true),
    ("Eltanin", 87833, "γ Dra", "al-Tinnīn", 17.94, 51.5, true),
    ("Vega", 91262, "α Lyr", "al-Nasr al-Wāqiʿ", 18.62, 38.8, true),
    ("Nunki", 92855, "σ Sgr", "", 18.92, -26.3, false),
    ("Altair", 97649, "α Aql", "al-Nasr al-Ṭāʾir", 19.85, 8.9, true),
    ("Peacock", 100751, "α Pav", "", 20.43, -56.7, true),
    ("Deneb", 102098, "α Cyg", "Dhanab al-Dajāja", 20.69, 45.3, true),
    ("Enif", 107315, "ε Peg", "al-Anf", 21.74, 9.9, true),
    ("Alnair", 109268, "α Gru", "al-Nayyir", 22.14, -47.0, true),
    ("Fomalhaut", 113368, "α PsA", "Fam al-Ḥūt", 22.96, -29.6, true),
    ("Scheat", 113881, "β Peg", "al-Sāq", 23.06, 28.1, true),
    ("Markab", 113963, "α Peg", "Matn al-Faras", 23.08, 15.2, true),
]

function vizier(source, hip, cols; attempts = 8)
    for m in MIRRORS, attempt = 1:attempts
        attempt > 1 && sleep(3attempt)
        url = "$m/viz-bin/asu-tsv?-source=$source&HIP=$hip&-out=$(join(cols, ','))"
        try
            io = IOBuffer()
            Downloads.download(url, io; timeout = 90)
            for line in eachline(IOBuffer(take!(io)))
                f = split(line, '	')
                length(f) == length(cols) || continue
                tryparse(Int, strip(f[1])) == hip || continue
                return [strip(x) for x in f]
            end
            @warn "no row returned" m attempt hip
        catch err
            @warn "mirror failed" m attempt err
            err isa Downloads.RequestError && occursin("connect", err.message) && break
        end
    end
    error("no VizieR mirror returned HIP $hip from $source")
end

function main(out = joinpath(@__DIR__, "..", "data", "stars.csv"))
    rows = String[]
    push!(rows, "hip,name,bayer,traditional,ra,dec,pmra,pmdec,parallax,vmag,default")
    jd1991 = sum(SOFA.epj2jd(1991.25))
    for (name, hip, bayer, trad, ra_h, dec_approx, default) in STARS
        a = vizier("I/311/hip2", hip, ["HIP", "RArad", "DErad", "Plx", "pmRA", "pmDE"])
        v = vizier("I/239/hip_main", hip, ["HIP", "Vmag"])
        ra, dec, plx, pmra, pmde = parse.(Float64, a[2:6])
        vmag = parse(Float64, v[2])
        # sanity check against the approximate position
        dra = abs(mod(ra - 15ra_h + 180, 360) - 180) * cosd(dec)
        (dra < 1.5 && abs(dec - dec_approx) < 1.5) || error(
            "$name: HIP $hip is at ($ra, $dec), expected near ($(15ra_h), $dec_approx)",
        )
        # epoch J1991.25 → J2000.0 (positions and proper motions)
        δ = deg2rad(dec)
        r = SOFA.pmsafe(
            deg2rad(ra),
            δ,
            pmra * Astrolabes.MAS2RAD / cos(δ),
            pmde * Astrolabes.MAS2RAD,
            plx / 1000,
            0.0,
            jd1991,
            0.0,
            Astrolabes.J2000_JD,
            0.0,
        )
        ra2, dec2 = rad2deg(r.ra), rad2deg(r.dec)
        pmra2 = r.pmras * cos(r.dec) / Astrolabes.MAS2RAD
        pmde2 = r.pmdec / Astrolabes.MAS2RAD
        push!(
            rows,
            @sprintf(
                "%d,%s,%s,%s,%.8f,%.8f,%.3f,%.3f,%.3f,%.2f,%s",
                hip,
                name,
                bayer,
                trad,
                ra2,
                dec2,
                pmra2,
                pmde2,
                plx,
                vmag,
                default
            )
        )
        println(rpad(name, 16), @sprintf(" V=%5.2f  α=%11.6f  δ=%+11.6f", vmag, ra2, dec2))
    end
    mkpath(dirname(out))
    write(out, join(rows, '\n') * '\n')
    println("wrote ", length(rows) - 1, " stars to ", out)
end

main()
