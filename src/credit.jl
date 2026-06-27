export AbstractCredit, Point, Percent, pt, pct, Credit, Mark



abstract type AbstractCredit end



"Points earned in the course."
struct Point <: AbstractCredit
    val::Float64
end
Point(x::Real) = Point(Float64(x))

"Shorthand construction with unit-like syntax: e.g., `Point(5.3)` ≡ `5.3pt`."
const pt = Point


"""
Percent earned of evaluation item.

**Automatically divides by 100 so that basis is [0, 1].**

## Examples
```
julia> Percent(83)
Percent(0.83)

julia> Percent(0.83)
Percent(0.0083)
```
"""
struct Percent <: AbstractCredit
    val::Float64

    function Percent(x::Float64; normalized::Bool=true)
        value = Float64(x)
        return new(normalized ? value / 100 : value)
    end
end
Percent(x::Real, normalized::Bool=true) = Percent(Float64(x); normalized=normalized)

"Shorthand construction with unit-like syntax: e.g., `Percent(5.3)` ≡ `5.3pct`."
const pct = Percent


"Type union of `Point` and `Percent` for cleaner function signatures."
const Credit = Union{Point, Percent}


"""
Encode redline marks of submitted work.

**Resolves `delta` to `Point` unless explicitly given as `Percent`.**
"""
struct Mark
    delta::Credit
    comment::String
end
Mark(delta::Real; comment::String="") = Mark(Point(delta), comment)
Mark(delta::Percent; comment::String="") = Mark(delta, comment)
