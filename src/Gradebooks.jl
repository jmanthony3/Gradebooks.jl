module Gradebooks

public uppercase2symbol, sanitize_string, sanitize2codify
export update
export Course, AcademicCalendarType, Term
public make_attendance, make_lectures
export Class

using Dates
import Printf: @sprintf

uppercase2symbol(s::AbstractString) = Symbol(uppercase("$s"))
sanitize_string(s::AbstractString) = lowercase(replace(string(s), r"[^[:alnum:]]+" => ""))
function sanitize2codify(s::AbstractString)
    articles = ["a", "an", "the"]
    conjuctions = ["for", "and", "nor", "but", "or", "yet", "so"]
    prepositions = ["of", "in", "for", "with", "on", "at", "from", "into", "during", "through", "without", "under", "over", "above", "below", "to"]
    forbidden = vcat(articles, conjuctions, prepositions)
    tokens = filter(!isempty, filter(s->lowercase(s) ∉ forbidden, split(filter(cn->!ispunct(cn) || cn ∈ ['{', '}'], s), " ")))
    firstword_idx = findfirst(t->(first(t) == '{' ? true : isletter(first(t))), tokens)
    if isnothing(firstword_idx)
        @error "After sanitization, no remaining tokens begin with a letter." s tokens
    end
    return map(t->(first(t) == '{' && last(t) == '}') ? t[begin+1:end-1] : (isdigit(first(t)) ? t : first(filter(!ispunct, t))), tokens[firstword_idx:end])
end
function update(x; kwargs...)
    T = typeof(x)
    fields = fieldnames(T)
    vals = map(f -> getproperty(x, f), fields)
    nt = NamedTuple{fields}(vals)
    return T((merge(nt, kwargs))...)
end

include("preferences.jl")
include("datetime.jl")
include("credit.jl")
include("letter_grades.jl")
include("people.jl")
include("assignments.jl")

@kwdef struct Course
    code::Symbol
    number::Integer
    name::String
    credits::Integer                = 3
    assignments::Vector{Assignment} = Assignment[]
    codename::Symbol                = Symbol("")
    function Course(code, number, name, credits, assignments, codename)
        return new(uppercase2symbol("$code"), Int(number), name, credits, assignments, uppercase2symbol("$codename"))
    end
end
Course(code, number, name; credits=3, assignments=Assignment[]) = Course(code, number, name, credits, assignments, uppercase2symbol("$code$number"))

@enum AcademicCalendarType begin
    Semester
    Quarter
    Trimester
    Block          # e.g., 4-week intensive blocks
    Session
    Module
    Other
end

@kwdef struct Term
    name::String                    # "Fall 2026", "Spring Quarter 2025-26", "Michaelmas 2026", etc.
    calendar_type::AcademicCalendarType
    year::Int                       # or academic_year::String e.g. "2025-2026"
    start::Date
    finish::Date
    holidays::Vector{Date}
    code::String                    # e.g. "FA26", "SP25", institutional code
    metadata::Dict{Symbol,Any} = Dict()  # for extra institution-specific info
end

make_attendance(name::AbstractString, points::Real, date::Date) = Attendance(name, Point(points), date)

function make_lectures(start::Date, finish::Date, holidays::Vector{Date}, frequency::Vector{Symbol}, points::Real=1.0)
    lecture_dates = filter(parse_date(start):Day(1):parse_date(finish)) do x
        occursin("$(DAYSYMBOLMAP(dayname(x)))", "$frequency") && (Date(x) ∉ vcat(holidays))
    end
    return map(x->make_attendance(x[1], points, x[2]), enumerate(lecture_dates))
end
function make_lectures(term::Term, frequency::Vector{Symbol}, points::Real=1.0)
    return make_lectures(term.start, term.finish, term.holidays, frequency, points)
end

struct Class
    course::Course
    term::Term
    section::Integer
    frequency::Vector{Symbol}
    time_start::Time
    time_finish::Time
    time_duration::Dates.CompoundPeriod
    lectures::Vector{Assignment}
    codename_short::Symbol
    codename_long::Symbol
    instructors::Vector{Instructor}
    primary_instructor::Instructor
    roster::Roster
    function Class(course, term, section, frequency, time_start, time_finish, time_duration, lectures, codename_short, codename_long, instructors, primary_instructor, roster)
        return new(course, term, section, frequency2symbols(frequency), time_start, time_finish, canonicalize(time_finish - time_start), lectures,
            uppercase2symbol("$codename_short"), uppercase2symbol("$codename_long"),
            instructors, primary_instructor, roster
        )
    end
end
function Class(course, term, section, frequency, time_start, time_finish, instructors::Vector{Instructor}, students::Vector{Student}, points::Real=1.0)
    return Class(course, term, section, frequency, time_start, time_finish, canonicalize(time_finish - time_start), make_lectures(term.start, term.finish, term.holidays, frequency, points),
        course.codename, uppercase2symbol(join(["$(course.codename)", first(uppercase("$term")) * (uppercase("$term")[1:2] == "SU" ? "u" : "") * last("$year", 2), @sprintf("%03d", section)], "-")),
        instructors, first(instructors), Roster(students)
    )
end

function update(class::Class; kwargs...)
    return update(class; kwargs...)
end

include("grades.jl")
include("gradebook.jl")
include("base.jl")
include("io.jl")
include("plots.jl")
include("reports.jl")

end # end of module
