module Gradebooks



export Course, AcademicCalendarType, Term
public make_attendance, make_lectures
export Class



using Dates
import Printf: @sprintf



include("preferences.jl")
include("utils.jl")
include("datetime.jl")
include("credit.jl")
include("letter_grades.jl")
include("people.jl")
include("assignments.jl")


"""

An academic quest prescribing assignments to students to grow and evaluate their understanding and ability to think critically unto completing a degree.

`credits` defaults to `COURSE_CREDITS` preference.
"""
struct Course
    code::Symbol
    number::Integer
    name::String
    credits::Integer
    assignments::Vector{Assignment}
    codename::Symbol
    function Course(code, number, name, credits, assignments, codename)
        return new(string_2uppercase_symbol("$code"), Int(number), name, Int(credits), assignments, string_2uppercase_symbol("$codename"))
    end
end
Course(code, number, name; credits=COURSE_CREDITS, assignments=Assignment[]) = Course(code, number, name, credits, assignments, string_2uppercase_symbol("$code$number"))

@enum AcademicCalendarType begin
    Semester
    Quarter
    Trimester
    Block
    Session
    Module
    Other
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
    new(name, calendar_type, year, parse_date(start), parse_date(finish), map(parse_date, holidays), string_2uppercase_symbol(string_sanitize(string_2codename(code))), metadata)
end
Term(name, calendar_type, year, start, finish, holidays, code; metadata=Dict()) = Term(name, calendar_type, year, start, finish, holidays, code, metadata=metadata)

make_attendance(name::AbstractString, points::Real, date::Date) = Attendance(name, Point(points), date)

function make_lectures(start::Date, finish::Date, holidays::Vector{Date}, frequency::Vector{Symbol}, points::Real=1.0)
    lecture_dates = filter(parse_date(start):Day(1):parse_date(finish)) do x
        occursin("$(DAYSYMBOLCODEMAP(dayname(x)))", "$frequency") && (Date(x) ∉ vcat(holidays))
    end
    return map(x->make_attendance(x[1], points, x[2]), enumerate(lecture_dates))
end
function make_lectures(term::Term, frequency::Vector{Symbol}, points::Real=1.0)
    return make_lectures(term.start, term.finish, term.holidays, frequency, points)
end

"Couples course with prescribing assignments in term offered to attending student roster."
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
        return new(course, term, section, frequency2codesymbols(frequency), time_start, time_finish, canonicalize(time_finish - time_start), lectures,
            string_2uppercase_symbol("$codename_short"), string_2uppercase_symbol("$codename_long"),
            instructors, primary_instructor, roster
        )
    end
end
function Class(course, term, section, frequency, time_start, time_finish, instructors::Vector{Instructor}, students::Vector{Student}, points::Real=1.0)
    return Class(course, term, section, frequency, time_start, time_finish, canonicalize(time_finish - time_start), make_lectures(term.start, term.finish, term.holidays, frequency, points),
        course.codename, string_2uppercase_symbol(join(["$(course.codename)", first(uppercase("$term")) * (uppercase("$term")[1:2] == "SU" ? "u" : "") * last("$year", 2), @sprintf("%03d", section)], "-")),
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
