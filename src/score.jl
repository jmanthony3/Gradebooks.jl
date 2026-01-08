export AbstractScore, Points, Percentage, score2letter, Score

import Base: +, -, *, /, ==, <, <=, zero, one, convert, promote_rule, show

abstract type AbstractScore <: Real end

struct Points <: AbstractScore
    x::Float64
end

struct Percentage <: AbstractScore
    x::Float64
    # Percentage{T} where {T<:AbstractScore{T}} = new(value > 1 ? 0.01value : value)
end

Points(x::Real) = Points(float(x))
Percentage(x::Real) = Percentage(float(x))

+(a::Points, b::Points) = Points(a.x + b.x)
-(a::Points, b::Points) = Points(a.x - b.x)
# *(a::Points, b::Points) = Points(a.x * b.x)
/(a::Points, b::Points) = Percentage(a.x / b.x)
+(a::Percentage, b::Percentage) = Percentage(a.x + b.x)
-(a::Percentage, b::Percentage) = Percentage(a.x - b.x)
# *(a::Percentage, b::Percentage) = Percentage(a.x * b.x)
# /(a::Percentage, b::Percentage) = Percentage(a.x / b.x)
*(a::Points, b::Percentage) = Points(a.x * b.x)
*(a::Percentage, b::Points) = b * a

==(a::Points, b::Points) = a.x == b.x
<(a::Points, b::Points) = a.x < b.x
<=(a::Points, b::Points) = a.x <= b.x
==(a::Percentage, b::Percentage) = a.x == b.x
<(a::Percentage, b::Percentage) = a.x < b.x
<=(a::Percentage, b::Percentage) = a.x <= b.x

zero(::Type{Points}) = Points(0.0)
one(::Type{Points}) = Points(1.0)
zero(::Type{Percentage}) = Percentage(0.0)
one(::Type{Percentage}) = Percentage(1.0)

show(io::IO, x::Points) = print(io, "Points(", x.x, ")")
show(io::IO, x::Percentage) = print(io, "Percentage(", x.x, ")")

Base.float(x::Points) = x.x
convert(::Type{Float64}, x::Points) = x.x
Base.float(x::Percentage) = x.x
convert(::Type{Float64}, x::Percentage) = x.x

promote_rule(::Type{Points}, ::Type{Float64}) = Float64
promote_rule(::Type{Points}, ::Type{T}) where {T<:Real} = promote_rule(Float64, T)
promote_rule(::Type{Percentage}, ::Type{Float64}) = Float64
promote_rule(::Type{Percentage}, ::Type{T}) where {T<:Real} = promote_rule(Float64, T)

# TODO: maybe overload `convert` instead?
score2letter(p::Percentage) = (p >= 0.90 ? 'A' : (p >= 0.80 ? 'B' : (p >= 0.70 ? 'C' : (p >= 0.60 ? 'D' : 'F'))))
score2letter(s::T, v::T) where {T<:Points} = score2letter(s.value / v.value)

struct Score <: AbstractScore
    score::Points
    value::Points
    percent::Percentage
    letter::Char
end
Score(percent::Percentage, value::Points) = Score(percent*value, value, percent, score2letter(percent))
Score(value::Points, percent::Percentage) = Score(percent, value)
Score(score::T, value::T) where {T<:Real} = Score(Percentage(score/value), value)
