struct InvalidPreference <: Exception
    preference
    available
    got
end

Base.showerror(io::IO, e::InvalidPreference) = print(io, "Invalid preference value for `", e.preference, "`. Please choose from: ", e.available, ". Given: \"", e.got, "\"")


struct AmbiguousMatch <: Exception
    target
    matches
end

Base.showerror(io::IO, e::AmbiguousMatch) = print(io, "Ambiguous match for `", e.target, "` against: ", e.matches, ". Please provide a more specific value.")


struct TemplateError <: Exception
    target
    candidates
end

Base.showerror(io::IO, e::TemplateError) = print(io, "Template '$(e.target)' not found. Searched: $(join(e.candidates, ", "))")


struct NotFound <: Exception
    msg::String
end

Base.showerror(io::IO, e::NotFound) = print(io, e.msg)


struct WeightError <: Exception
end
