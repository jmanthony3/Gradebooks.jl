export AbstractCredit, Point, Percent, pt, pct, Credit, Mark

abstract type AbstractCredit end

struct Point <: AbstractCredit
    val::Float64
end

struct Percent <: AbstractCredit
    val::Float64
end

const pt = Point
const pct = Percent

Point(x::Real) = Point(Float64(x))
Percent(x::Real) = Percent(Float64(x) / 100)

const Credit = Union{Point, Percent}

struct Mark
    delta::Credit
    comment::String
end
Mark(delta::Real; comment::String="") = Mark(Point(delta), comment)
Mark(delta::Percent; comment::String="") = Mark(delta, comment)
