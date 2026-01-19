export AbstractScore, Points, Percentage
export Question
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

struct Question{T<:AbstractScore}
    name::String
    value::T
    codename::Symbol
    function Question{T}(name, value, codename) where {T<:AbstractScore}
        codename = if isa(codename, Symbol)
            codename
        elseif isa(codename, String)
            articles = ["a", "an", "the"]
            conjuctions = ["for", "and", "nor", "but", "or", "yet", "so"]
            prepositions = ["of", "in", "for", "with", "on", "at", "from", "into", "during", "through", "without", "under", "over", "above", "below", "to"]
            forbidden = vcat(articles, conjuctions, prepositions)
            tokens = filter(s->lowercase(s) ∉ forbidden, split(filter(cn->!ispunct(cn) || cn ∈ ['{', '}'], codename), " "))
            firstword_idx = findfirst(t->(first(t) == '{' ? true : isletter(first(t))), tokens)
            if isnothing(firstword_idx)
                @error "After sanitization, no remaining tokens begin with a letter." codename tokens
            end
            uppercase2symbol(mapreduce(t->(first(t) == '{' && last(t) == '}') ? t[begin+1:end-1] : (isdigit(first(t)) ? t : first(filter(!ispunct, t))), *, tokens[firstword_idx:end]))
        else
            @error "`codename` must be of type Symbol or String."
        end
        return new{T}(join(map(t->(first(t, 2) == "\\{" && last(t, 2) == "\\}") ? "{$(t[begin+2:end-2])}" : ((first(t) == '{' && last(t) == '}') ? t[begin+1:end-1] : t), split(name, " ")), " "), Points(value), uppercase2symbol(codename))
    end
end
Question(name, value) = Question{typeof(value)}(name, value, name)

abstract type AbstractMark end
struct Grant{T<:AbstractScore} <: AbstractMark # ,V<:AbstractScore} <: AbstractMark
    mark::T
    # value::V
end
Grant(::T, mark::T) where {T<:AbstractScore} = Grant{T}(mark)
struct Subtract{T<:AbstractScore} <: AbstractMark # ,V<:AbstractScore} <: AbstractMark
    mark::T
    # value::V
end
Subtract(::T, mark::T) where {T<:AbstractScore} = Subtract{T}(mark)

struct Tally{T<:AbstractScore,M<:AbstractMark,V<:AbstractScore}
    question::Question{T}
    mark::M # {V}
    comment::String
end

Tally(question::Question{T1}, mark::T2, comment="") where {T1<:AbstractScore,T2<:AbstractMark} = Tally{T1,T2,typeof(mark.mark)}(question, mark, comment)

function tally(tallies::Vararg{Tally{T,M,T}}) where {T<:Points,M<:AbstractMark}
    grant = mapreduce(y->y.mark.mark, +, filter(x->isa(x.mark, Grant{T}), tallies); init=zero(T))
    subtract = mapreduce(y->y.question.value - y.mark.mark, +, filter(x->isa(x.mark, Subtract{T}), tallies); init=zero(T))
    value = mapreduce(x->x.question.value, +, tallies)
    return (grant + subtract) / value
end
function tally(tallies::Vararg{Tally{T,M,T}}) where {T<:Percentage,M<:AbstractMark}
    grant = mapreduce(y->y.mark.mark * y.question.value, +, filter(x->isa(x.mark, Grant{T}), tallies); init=zero(T))
    subtract = mapreduce(y->y.mark.mark * y.question.value, +, filter(x->isa(x.mark, Subtract{T}), tallies); init=zero(T))
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
    comment::String
end
Score(percent::Percentage, value::Points; comment="") = Score(percent*value, value, percent, percent, comment)
Score(value::Points, percent::Percentage; comment="") = Score(percent, value; comment=comment)
Score(score::T, value::T; comment="") where {T<:Real} = ((s, v) = Points.([score, value]); p = s/v; Score(s, v, p, p, comment))
