module Gradebooks

export uppercase2symbol
export Course, Class
export withdraw

import Printf: @sprintf

# configuration preferences for environment/workspace
include("preferences.jl")
# types and overloads
include("score.jl")
include("datetime.jl")
include("people.jl")

uppercase2symbol(s) = Symbol(uppercase("$s"))

struct Course
    code::Symbol
    number::Integer
    name::String
    credits::Integer
    codename::Symbol
    function Course(code, number, name, credits, codename)
        return new(uppercase2symbol("$code"), Int(number), name, credits, uppercase2symbol("$codename"))
    end
end
Course(code, number, name, credits=3) = Course(code, number, name, credits, uppercase2symbol("$code$number"))

struct Class
    course::Course
    section::Integer
    semester::Symbol
    year::Integer
    frequency::Symbol
    time_start::Time
    time_finish::Time
    time_duration::Dates.CompoundPeriod
    codename_short::Symbol
    codename_long::Symbol
    instructors::Vector{Instructor}
    primary_instructor::Instructor
    students::Vector{Student}
    roster::Vector{Student}
    function Class(course, section, semester, year, frequency, time_start, time_finish, time_duration, codename_short, codename_long, instructors, primary_instructor, students, roster)
        time_start, time_finish = map(parse_time, [time_start, time_finish])
        return new(course, section, uppercase2symbol(semester), year, dayname2codename(frequency), time_start, time_finish, canonicalize(time_finish - time_start),
            uppercase2symbol("$codename_short"), uppercase2symbol("$codename_long"),
            instructors, primary_instructor, students, roster
        )
    end
end
function Class(course, section, semester, year, frequency, time_start, time_finish, time_duration, roster, instructors::Vararg{Instructor})
    return Class(course, section, semester, year, frequency, time_start, time_finish, time_duration,
        course.codename, uppercase2symbol(join(["$(course.codename)", @sprintf("%03d", section), first(uppercase("$semester")) * (uppercase("$semester")[1:2] == "SU" ? "u" : "") * last("$year", 2)], "-")),
        [instructors...], first([instructors...]), roster, roster
    )
end
function Class(course, section, semester, year, frequency, time_start, time_duration::Dates.CompoundPeriod, roster, instructors::Vararg{Instructor})
    return Class(course, section, semester, year, frequency, time_start, time_start + time_duration, time_duration, roster, instructors...)
end

include("assignments.jl")
include("gradebook.jl")


function withdraw(roster, class, gb, student)
    deleteat!(gb.raw_score, findfirst(x->x.name_family == student.name_family, roster))
    deleteat!(gb.penalty, findfirst(x->x.name_family == student.name_family, roster))
    deleteat!(gb.total, findfirst(x->x.name_family == student.name_family, roster))
    deleteat!(roster, findfirst(x->x.name_family == student.name_family, roster))
    class = Class(class.course, class.section, class.semester, class.year, class.frequency, class.time_start, class.time_duration, roster, class.instructors...)
    return roster, class, gb
end

function withdraw(roster, class, gb, teams, student)
    for (i, team) in enumerate(teams)
        if student ∈ team.students
            team_students = team.students
            deleteat!(team_students, findfirst(x->x == student, team_students))
            teams[i] = Team(team.name, team_students, team.codename)
        end
    end
    return withdraw(roster, class, gb, student)..., teams
end


include("base.jl")
include("io.jl")
include("plots.jl")
include("reports.jl")

end # end of module
