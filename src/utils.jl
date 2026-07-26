# export string_sanitize, string2uppercase_symbol, string2codename
export update



"Sanitizes a string by stripping all non-alphanumeric characters."
string_sanitize(s::AbstractString) = replace(Base.string(s), r"[^[:alnum:]]+" => "")

"Converts string to an uppercase symbol."
string2uppercase_symbol(s::AbstractString) = isa(s, Symbol) ? s : Symbol(uppercase(string_sanitize(s)))

"Codifies string like one reads the title of a book but includes LaTeX-style exceptions with `{` and `}` pairs."
function string2codename(s::AbstractString)
    articles = ["a", "an", "the"]
    conjuctions = ["for", "and", "nor", "but", "or", "yet", "so"]
    prepositions = ["of", "in", "for", "with", "on", "at", "from", "into", "during", "through", "without", "under", "over", "above", "below", "to"]
    forbidden = vcat(articles, conjuctions, prepositions)
    tokens = filter(!isempty, filter(s->lowercase(s) ∉ forbidden, split(filter(cn->!ispunct(cn) || cn ∈ ['{', '}'], s), " ")))
    firstword_idx = findfirst(t->(first(t) == '{' ? true : isletter(first(t))), tokens)
    if isnothing(firstword_idx)
        @error "After sanitization, no remaining tokens begin with a letter." tokens
        error("Could not parse input, s=", s)
    end
    return string2uppercase_symbol(join(map(t->(first(t) == '{' && last(t) == '}') ? t[begin+1:end-1] : (isdigit(first(t)) ? t : first(filter(!ispunct, t))), tokens[firstword_idx:end])))
end
function string2codename(s::Symbol)
    return string2codename("{" * String(s) * "}")
end


"Modifies the field(s) of an immutable `struct` and returns a new one."
function _update(x; kwargs...)
    T = typeof(x)
    fields = fieldnames(T)
    vals = map(f -> getproperty(x, f), fields)
    nt = NamedTuple{fields}(vals)
    return T((merge(nt, kwargs))...)
end
update(x; kwargs...) = _update(x; kwargs...)
