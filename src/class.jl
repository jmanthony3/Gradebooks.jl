export Course, AcademicCalendarType, Term
public make_attendance, make_lectures
export Class



"""
An academic quest prescribing assignments to students to grow and evaluate their understanding and ability to think critically unto completing a degree.

`credits` defaults to `COURSE_CREDITS` preference.
"""
struct Course <: AbstractGradebookNode
    code::Symbol
    number::Integer
    name::String
    credits::Integer
    assignments::Vector{Assignment}
    codename::Symbol

    function Course(code, number, name, credits, assignments, codename)
        return new(string2uppercase_symbol("$code"), Int(number), name, Int(credits), assignments, string2uppercase_symbol("$codename"))
    end
end
Course(code, number, name; credits=COURSE_CREDITS, assignments=Assignment[]) = Course(code, number, name, credits, assignments, string2uppercase_symbol("$code$number"))


@enum AcademicCalendarType begin
    Semester
    Quarter
    Trimester
    Block
    Session
    Module
    Other_Calendar
end

"Calendrical discretization of academic year."
struct Term
    name::String
    calendar_type::AcademicCalendarType
    year::Integer
    start::Date
    finish::Date
    holidays::Vector{Date}
    code::Symbol
    metadata::Dict{Symbol,Any}
    Term(name, calendar_type, year, start, finish, holidays, code, metadata) = new(name, calendar_type, year, parse_date(start), parse_date(finish), map(parse_date, vcat(holidays...)), isa(code, Symbol) ? code : string2codename(code), metadata)
end
Term(name, calendar_type, year, start, finish, holidays, code; metadata=Dict()) = Term(name, calendar_type, year, start, finish, holidays, code, metadata)

make_attendance(name::AbstractString, date::Date) = Attendance(name, Point(1.0), date)

function make_lectures(start::Date, finish::Date, frequency::Vector{Symbol}, holidays::Vector{Date}=Date[])
    lecture_dates = filter(parse_date(start):Day(1):parse_date(finish)) do x
        occursin("$(DAYSYMBOLCODEMAP[dayname(x)])", "$frequency") && (Date(x) ∉ vcat(holidays))
    end
    return map(x->make_attendance("Lecture $(x[1])", x[2]), enumerate(lecture_dates))
end
function make_lectures(term::Term, frequency::Vector{Symbol})
    return make_lectures(term.start, term.finish, frequency, term.holidays)
end

"Couples course with prescribing assignments in term offered to attending student roster."
struct Class <: AbstractGradebookNode
    course::Course
    term::Term
    section::Integer
    frequency::Vector{Symbol}
    time_start::Time
    time_finish::Time
    time_duration::Dates.CompoundPeriod
    instructors::Vector{Instructor}
    roster::Roster
    teams::Vector{Team}

    function Class(course, term, section, frequency, time_start, time_finish, time_duration, instructors, roster, teams)
        return new(course, term, section, frequency2codesymbols(frequency), time_start, time_finish, canonicalize(time_finish - time_start),
            instructors, roster, teams
        )
    end
end
function Class(course, term, section, frequency, time_start, time_finish, instructors::Vector{Instructor}, students::Vector{Student}, teams::Vector{Team}=Team[])
    return Class(course, term, section, frequency, time_start, time_finish, canonicalize(time_finish - time_start), instructors, Roster(students), teams
    )
end

function Base.getproperty(c::Class, sym::Symbol)
    if sym == :lectures
        term = getfield(c, :term)
        return make_lectures(getfield(term, :start), getfield(term, :finish), getfield(c, :frequency), getfield(term, :holidays))
    elseif sym == :codename_short
        return getfield(getfield(c, :course), :codename)
    elseif sym == :codename_long
        term = getfield(c, :term)
        return string2uppercase_symbol(join(["$(getfield(getfield(c, :course), :codename))", first(uppercase("$(getfield(term, :name))")) * (uppercase("$(getfield(term, :name))")[1:2] == "SU" ? "u" : "") * last("$(getfield(term, :year))", 2), @sprintf("%03d", getfield(c, :section))], "-"))
    elseif sym == :primary_instructor
        return first(getfield(c, :instructors))
    else
        return getfield(c, sym)
    end
end

Base.propertynames(c::Class) = (:course, :term, :section, :frequency, :time_start, :time_finish, :time_duration, :lectures, :codename_short, :codename_long, :primary_instructor, :instructors, :roster, :teams)


update(class::Class; kwargs...) = _update(class; kwargs...)
get_student(identifier::String, class::Class; threshold=STRING_MATCH_THRESHOLD) = get_student(identifier, class.roster; threshold=threshold)
