"""
    VerificationReport(title, checks)

A collection of [`CurveCheck`](@ref)s. `passed(report)` is true when every check passes;
`show` prints a table.
"""
struct VerificationReport
    title::String
    checks::Vector{CurveCheck}
end

passed(r::VerificationReport) = !isempty(r.checks) && all(c -> c.passed, r.checks)
failures(r::VerificationReport) = filter(c -> !c.passed, r.checks)

function Base.show(io::IO, ::MIME"text/plain", r::VerificationReport)
    nfail = count(c -> !c.passed, r.checks)
    println(io, r.title)
    println(
        io,
        "  ",
        length(r.checks),
        " checks, ",
        nfail,
        " failed — ",
        passed(r) ? "PASS" : "FAIL",
    )
    w = maximum((length(c.label) for c in r.checks); init = 5)
    println(
        io,
        "  ",
        rpad("check", w),
        "  ",
        lpad("n", 6),
        "  ",
        lpad("max error", 10),
        "  ",
        lpad("tol", 8),
        "  result",
    )
    for c in r.checks
        println(
            io,
            "  ",
            rpad(c.label, w),
            "  ",
            lpad(c.n, 6),
            "  ",
            lpad(@sprintf("%.2e", c.max_err), 10),
            "  ",
            lpad(@sprintf("%.0e", c.tol), 8),
            "  ",
            c.passed ? "pass" : "FAIL",
        )
    end
    return nothing
end

Base.show(io::IO, r::VerificationReport) = print(
    io,
    "VerificationReport(\"",
    r.title,
    "\", ",
    length(r.checks),
    " checks, ",
    passed(r) ? "PASS" : "FAIL",
    ")",
)
