export string_sanitize, string_2uppercase_symbol, string_2codename
export update



"Sanitizes a string by stripping all non-alphanumeric characters."
string_sanitize(s::AbstractString) = replace(string(s), r"[^[:alnum:]]+" => "")

"Converts string to an uppercase symbol."
string_2uppercase_symbol(s::AbstractString) = isa(s, Symbol) ? s : Symbol(uppercase(string_sanitize(s)))

"Codifies string like one reads the title of a book but includes LaTeX-style exceptions with `{` and `}` pairs."
function string_2codename(s::AbstractString)
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
    return map(t->(first(t) == '{' && last(t) == '}') ? t[begin+1:end-1] : (isdigit(first(t)) ? t : first(filter(!ispunct, t))), tokens[firstword_idx:end])
end

"Modifies the field(s) of an immutable `struct` and returns a new one."
function update(x; kwargs...)
    T = typeof(x)
    fields = fieldnames(T)
    vals = map(f -> getproperty(x, f), fields)
    nt = NamedTuple{fields}(vals)
    return T((merge(nt, kwargs))...)
end
