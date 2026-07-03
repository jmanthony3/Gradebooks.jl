module Gradebooks





export Course, AcademicCalendarType, Term
public make_attendance, make_lectures
export Class
export update, withdraw!, reinstate!



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
    Term(name, calendar_type, year, start, finish, holidays, code, metadata) = new(name, calendar_type, year, parse_date(start), parse_date(finish), map(parse_date, vcat(holidays...)), isa(code, Symbol) ? code : string_2codename(code), metadata)
end
Term(name, calendar_type, year, start, finish, holidays, code; metadata=Dict()) = Term(name, calendar_type, year, start, finish, holidays, code, metadata)

make_attendance(name::AbstractString, points::Real, date::Date) = Attendance(name, Point(points), date)

function make_lectures(start::Date, finish::Date, holidays::Vector{Date}, frequency::Vector{Symbol}, points::Real=1.0)
    lecture_dates = filter(parse_date(start):Day(1):parse_date(finish)) do x
        occursin("$(DAYSYMBOLCODEMAP[dayname(x)])", "$frequency") && (Date(x) ∉ vcat(holidays))
    end
    return map(x->make_attendance("Lecture $(x[1])", points, x[2]), enumerate(lecture_dates))
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
    primary_instructor::Instructor
    instructors::Vector{Instructor}
    roster::Roster
    teams::Vector{Team}
    function Class(course, term, section, frequency, time_start, time_finish, time_duration, lectures, codename_short, codename_long, primary_instructor, instructors, roster, teams)
        return new(course, term, section, frequency2codesymbols(frequency), time_start, time_finish, canonicalize(time_finish - time_start), lectures,
            string_2uppercase_symbol("$codename_short"), string_2uppercase_symbol("$codename_long"),
            primary_instructor, instructors, roster, teams
        )
    end
end
function Class(course, term, section, frequency, time_start, time_finish, instructors::Vector{Instructor}, students::Vector{Student}, teams::Vector{Team}=Team[], points::Real=1.0)
    return Class(course, term, section, frequency, time_start, time_finish, canonicalize(time_finish - time_start), make_lectures(term.start, term.finish, term.holidays, frequency, points),
        course.codename, string_2uppercase_symbol(join(["$(course.codename)", first(uppercase("$term")) * (uppercase("$term")[1:2] == "SU" ? "u" : "") * last("$year", 2), @sprintf("%03d", section)], "-")),
        first(instructors), instructors, Roster(students), teams
    )
end


update(class::Class; kwargs...) = _update(class; kwargs...)


include("grades.jl")
include("gradebook.jl")
include("attendance.jl")


function withdraw!(gb::Gradebook, student::Union{Student, String}; date::Date = today(), threshold=STRING_MATCH_THRESHOLD)
    if student isa String
        student = get_student(student, gb.class.roster; threshold=threshold)
    end
    student.final_grade = LetterGrade("W")
    student.enrollment_status = withdrawn
    student.withdrawal_date = date

    # Optionally record a W grade automatically
    if haskey(gb.grades_dict, student)  # or however you index grades
        g = gb.grades_dict[student]
        g.submission.score.letter = LetterGrade("W")
    end

    grades_sync(gb; threshold=threshold)  # or just mark dirty
    return nothing
end

function reinstate!(gb::Gradebook, student::Union{Student, String}; date::Date = today(), threshold=STRING_MATCH_THRESHOLD)
    if student isa String
        student = get_student(student, gb.class.roster; threshold=threshold)
    end
    student.notes[:withdrawal_date] = student.withdrawal_date  # preserve original withdrawal date
    student.notes[:reinstatement_date] = date  # or however you want to track reinstatement
    student.enrollment_status = active
    student.withdrawal_date = nothing
    # Optionally clear the W or let instructor decide
    grades_sync(gb; threshold=threshold)
    return nothing
end


include("base.jl")
include("io.jl")
include("plots.jl")
include("reports.jl")





end # end of module
