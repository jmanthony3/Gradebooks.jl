export AbstractScore, Points, Percentage
export AbstractMark, Grant, Subtract
export Tally, tally
export score2letter, Score

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

abstract type AbstractMark end
struct Grant{T<:AbstractScore} <: AbstractMark # ,V<:AbstractScore} <: AbstractMark
    mark::T
    # value::V
end
Grant(mark::T) where {T<:AbstractScore} = Grant{T}(mark)
struct Subtract{T<:AbstractScore} <: AbstractMark # ,V<:AbstractScore} <: AbstractMark
    mark::T
    # value::V
end
Subtract(mark::T) where {T<:AbstractScore} = Subtract{T}(mark)

struct Tally{T<:AbstractScore,M<:AbstractMark,V<:AbstractScore}
    question::Question{T1}
    mark::M{T2}
end

Tally(question::Question{T1}, mark::T2) where {T1<:AbstractScore,T2<:AbstractMark{<:AbstractScore}} = Tally{T1,T2,eltype(mark)}(question, mark)

function tally(tallies::Vararg{Tally{T,M,T}}) where {T<:Points,M<:AbstractMark}
    grant = mapreduce(y->y.mark, +, filter(x->isa(x.mark, Grant{T}), tallies); init=zero(T))
    subtract = mapreduce(y->y.mark, +, filter(x->isa(x.mark, Subtract{T}), tallies); init=zero(T))
    value = mapreduce(x->x.question.value, +, tallies)
    return (grant - subtract) / value
end
function tally(tallies::Vararg{Tally{T,M,T}}) where {T<:Percentage,M<:AbstractMark}
    grant = mapreduce(y->y.mark * y.question.value, +, filter(x->isa(x.mark, Grant{T}), tallies); init=zero(T))
    subtract = mapreduce(y->y.mark * y.question.value, +, filter(x->isa(x.mark, Subtract{T}), tallies); init=zero(T))
    value = mapreduce(x->x.question.value, +, tallies)
    return grant - subtract
end
function tally(tallies::Vararg{Tally{T,M,V}}) where {T<:Points,M<:AbstractMark,V<:Percentage}
    grant = mapreduce(y->y.mark.mark * y.question.value, +, filter(x->isa(x.mark, Grant{V}), tallies); init=zero(T))
    subtract = mapreduce(y->y.mark.mark * y.question.value, +, filter(x->isa(x.mark, Subtract{V}), tallies); init=zero(T))
    value = mapreduce(x->x.question.value, +, tallies)
    return (grant - subtract) / value
end
function tally(tallies::Vararg{Tally{T,M,V}}) where {T<:Percentage,M<:AbstractMark,V<:Percentage}
    grant = mapreduce(y->y.mark.mark * y.question.value, +, filter(x->isa(x.mark, Grant{V}), tallies); init=zero(T))
    subtract = mapreduce(y->y.mark.mark * y.question.value, +, filter(x->isa(x.mark, Subtract{V}), tallies); init=zero(T))
    value = mapreduce(x->x.question.value, +, tallies)
    return grant - subtract
end

score2letter(p::Percentage) = convert(Char, p)
score2letter(s::T, v::T) where {T<:Points} = score2letter(s / v)

struct Score
    score::Points
    value::Points
    percent::Percentage
    letter::Char
end
Score(percent::Percentage, value::Points) = Score(percent*value, value, percent, percent)
Score(value::Points, percent::Percentage) = Score(percent, value)
Score(score::T, value::T) where {T<:Real} = ((s, v) = Points.([score, value]); p = s/v; Score(s, v, p, p))
Score(assignment::Assignment, tallies::Vararg{Tally{T,M,V}}) where {T<:AbstractScore,M<:AbstractMark,V<:AbstractScore} = Score(assignment.value, map(tally, tallies))
