# The sample-and-project verification harness.
#
# Forward check:  sample the defining set on the sphere, project each point with the
#                 projection (not with the plate formulas), and measure its distance to
#                 the drawn primitives.
# Backward check: sample the drawn primitives, un-project each point back to the sphere
#                 and evaluate the defining equation there.
# Together they show the drawing is the projected set: nothing missing, nothing extra.

"""
    CurveCheck

Result of one verification check: `label`, number of samples `n`, the largest error
`max_err`, the tolerance `tol` and whether it `passed`.
"""
struct CurveCheck
    label::String
    n::Int
    max_err::Float64
    tol::Float64
    passed::Bool
end

function CurveCheck(label::AbstractString, errs::AbstractVector{<:Real}, tol::Real)
    isempty(errs) && return CurveCheck(String(label), 0, NaN, tol, false)
    m = maximum(errs)
    return CurveCheck(String(label), length(errs), m, tol, m <= tol)
end

Base.show(io::IO, c::CurveCheck) = print(
    io,
    "CurveCheck(\"",
    c.label,
    "\", n=",
    c.n,
    ", max_err=",
    c.max_err,
    ", tol=",
    c.tol,
    c.passed ? ", PASS)" : ", FAIL)",
)

"""
    check_curve(prims, points; tol, label = "") -> CurveCheck

Forward check: every sample point (a projected point of the defining sphere set) must
lie within `tol` of the drawn primitive(s). A check with no samples fails.
"""
function check_curve(
    prims::AbstractVector{<:Primitive},
    points::AbstractVector{Pt};
    tol::Real,
    label::AbstractString = "",
)
    return CurveCheck(label, [distance_to(prims, p) for p in points], tol)
end
check_curve(prim::Primitive, points::AbstractVector{Pt}; kw...) =
    check_curve([prim], points; kw...)

"""
    check_point(p, q; tol, label = "") -> CurveCheck

The drawn point `p` must coincide with the projected point `q` within `tol`.
"""
check_point(p::Pt, q::Pt; tol::Real, label::AbstractString = "") =
    CurveCheck(label, [norm2(p - q)], tol)

"""
    check_definition(prims, residual; n = 200, tol, label = "") -> CurveCheck

Backward check: sample `n` points on each primitive and require
`abs(residual(point)) <= tol` everywhere. `residual` usually un-projects the point and
evaluates the defining equation (e.g. altitude − a, in degrees).
"""
function check_definition(
    prims::AbstractVector{<:Primitive},
    residual;
    n::Integer = 200,
    tol::Real,
    label::AbstractString = "",
)
    errs = Float64[]
    for q in prims, p in sample_points(q, n)
        push!(errs, abs(residual(p)))
    end
    return CurveCheck(label, errs, tol)
end
