export AbstractScore, Points, Percentage, score2letter, Score

abstract type AbstractScore <: Real end

struct Points <: AbstractScore
    val::Float64
end

struct Percentage <: AbstractScore
    val::Float64
    # Percentage{T} where {T<:AbstractScore{T}} = new(value > 1 ? 0.01value : value)
end

Points(x::Real) = Points(float(x))
Percentage(x::Real) = Percentage(float(x))

score2letter(p::Percentage) = convert(Char, p)
score2letter(s::T, v::T) where {T<:Points} = score2letter(s / v)

struct Score <: AbstractScore
    score::Points
    value::Points
    percent::Percentage
    letter::Char
end
Score(percent::Percentage, value::Points) = Score(percent*value, value, percent, percent)
Score(value::Points, percent::Percentage) = Score(percent, value)
Score(score::T, value::T) where {T<:Real} = ((s, v) = Points.([score, value]); p = s/v; Score(s, v, p, p))
