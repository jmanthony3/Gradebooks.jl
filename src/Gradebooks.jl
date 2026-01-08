module Gradebooks

export uppercase2symbol
export Course, Class

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
    codename::Symbol
    function Course(code, number, name, codename)
        return new(uppercase2symbol("$code")), Int(number), name, uppercase2symbol("$codename")
    end
end
Course(code, number, name) = Course(code, number, name, "$code$number")

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
    function Class(course, section, semester, year, frequency, time_start, time_finish, time_duration, codename_short, codename_long, primary_instructor, instructors, students, roster)
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
        [instructors...], first(instructors), roster, roster
    )
end
function Class(course, section, semester, year, frequency, time_start, time_duration::Dates.CompoundPeriod, roster, instructors::Vararg{Instructor})
    return Class(course, section, semester, year, frequency, time_start, time_start + time_duration, time_duration, roster, instructors...)
end

include("assignments.jl")
include("gradebook.jl")
include("io.jl")
include("plots.jl")
include("reports.jl")

end # end of module
