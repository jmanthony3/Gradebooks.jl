export AbstractScore, Points, Percentage, Score, score_letter


abstract type AbstractScore{T<:Real} end

struct Points{T} <: AbstractScore{T}
    value::T
end

struct Percentage{T} <: AbstractScore{T}
    value::T
    # Percentage{T} where {T<:AbstractScore{T}} = new(value > 1 ? 0.01value : value)
end

score_letter(p::T) where {T<:Real} = (p >= 0.90 ? 'A' : (p >= 0.80 ? 'B' : (p >= 0.70 ? 'C' : (p >= 0.60 ? 'D' : 'F'))))
score_letter(p::Percentage) = score_letter(p.value)
score_letter(s::T, v::T) where {T<:Points} = score_letter(s.value / v.value)

struct Score{T} <: AbstractScore{T}
    score::Points{T}
    value::Points{T}
    percent::Percentage{T}
    letter::Char
end
Score(score::Points{T}, value::Points{T}) where {T<:Real} = (p = Percentage{T}(score/value); Score{T}(score, value, p, score_letter(p)))
Score(percent::Percentage{T}, value::Points{T}) where {T<:Real} = Score{T}(Points{T}(percent.value*value.value), value, percent, score_letter(percent))
