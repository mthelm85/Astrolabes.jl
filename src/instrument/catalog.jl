# The shipped star catalogue (data/stars.csv, built by scripts/build_star_catalog.jl).

"""
    CatalogStar

A row of the shipped catalogue: the [`Star`](@ref) (J2000 astrometry), its Hipparcos
number, Bayer designation, traditional (Arabic-derived) name and whether it belongs to
the default rete set.
"""
struct CatalogStar
    star::Star
    hip::Int
    bayer::String
    traditional::String
    default::Bool
end

const CATALOG_PATH = joinpath(@__DIR__, "..", "..", "data", "stars.csv")
const _CATALOG = Ref{Vector{CatalogStar}}()

"""
    load_catalog(path = CATALOG_PATH) -> Vector{CatalogStar}

Read a catalogue CSV with columns `hip,name,bayer,traditional,ra,dec,pmra,pmdec,
parallax,vmag,default` (degrees, mas/yr, mas).
"""
function load_catalog(path::AbstractString = CATALOG_PATH)
    lines = readlines(path)
    header = split(lines[1], ',')
    col(n) = findfirst(==(n), header)
    out = CatalogStar[]
    for line in lines[2:end]
        isempty(strip(line)) && continue
        f = split(line, ',')
        g(n) = f[col(n)]
        num(n) = parse(Float64, g(n))
        s = Star(
            String(g("name")),
            num("ra"),
            num("dec");
            pmra = num("pmra"),
            pmdec = num("pmdec"),
            parallax = num("parallax"),
            vmag = num("vmag"),
        )
        push!(
            out,
            CatalogStar(
                s,
                parse(Int, g("hip")),
                String(g("bayer")),
                String(g("traditional")),
                parse(Bool, g("default")),
            ),
        )
    end
    return out
end

"The shipped catalogue (loaded once)."
function star_catalog()
    isassigned(_CATALOG) || (_CATALOG[] = load_catalog())
    return _CATALOG[]
end

"""
    catalog_stars(sel = :default) -> Vector{Star}

Stars from the shipped catalogue: `:default` (the default rete set), `:all`, or a list of
names (IAU names, case-insensitive).
"""
function catalog_stars(sel = :default)
    cat = star_catalog()
    sel === :default && return [c.star for c in cat if c.default]
    sel === :all && return [c.star for c in cat]
    want = lowercase.(String.(collect(sel)))
    found = [c.star for c in cat if lowercase(c.star.name) in want]
    missing_ = setdiff(want, lowercase.(getfield.(found, :name)))
    isempty(missing_) ||
        throw(ArgumentError("not in the catalogue: $(join(missing_, ", "))"))
    return found
end

"""
    find_star(name) -> Star

Look up a star of the shipped catalogue by IAU name (case-insensitive).
"""
find_star(name::AbstractString) = only(catalog_stars([name]))

"Traditional name of a catalogue star (empty if none)."
traditional_name(name::AbstractString) = traditional_name(find_star(name))
function traditional_name(s::Star)
    for c in star_catalog()
        c.star.name == s.name && return c.traditional
    end
    return ""
end
