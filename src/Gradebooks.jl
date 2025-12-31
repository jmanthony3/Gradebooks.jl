module Gradebooks

using CSV
using DataFrames
using Dates
using Distributed
using Glob
using JSON
using PrettyTables
using Printf
using RecipesBase
# using Plots; gr()

# default(
#     fontfamily="Computer Modern",
#     linewidth=1,
#     framestyle=:box,
#     label=nothing,
#     grid=false)
# scalefontsizes(1.3)

abstract type AbstractPerson end

name(firstname, lastname; title="", suffix="") = (title == "" ? "" : "$title ") * join([firstname, lastname]) * (suffix == "" ? "" : ", $suffix")
codename(firstname, lastname) = uppercase(join(map(s->first(s, 1), [firstname, lastname])))

struct Instructor <: AbstractPerson
    firstname
    lastname
    title
    suffix
    email
    phone
    name
    codename
    job_title
    Instructor(firstname, lastname; title="", suffix="", initials="", email="", phone="", job_title="") = new(firstname, lastname, title, suffix, email, phone, name(firstname, lastname; title=title, suffix=suffix), isempty(initials) ? codename(firstname, lastname) : initials, job_title)
end

struct Student <: AbstractPerson
    firstname
    lastname
    title
    suffix
    email
    phone
    name
    codename
    discipline
    Student(firstname, lastname; title="", suffix="", initials="", email="", phone="", discipline="") = new(firstname, lastname, title, suffix, email, phone, name(firstname, lastname; title=title, suffix=suffix), isempty(initials) ? codename(firstname, lastname) : initials, discipline)
end

struct Course
    code
    number
    name
    codename
    Course(code, number, name) = new(code, number, name, uppercase("$code$number"))
end

struct Class
    course::Course
    section
    semester
    year
    codename_short
    codename_long
    instructor::Instructor
    students::Vector{Student}
    roster::Vector{Student}
    function Class(course::Course, section, semester, year, instructor::Instructor, students::Vector{Student})
        section_padded = @sprintf("%03d", section)
        return new(
            course, "$section", semester, year,
            course.codename, join(uppercase.(["$code$number", "$section_padded", first("$semester") * last("$year", 2)], "-")),
            instructor, students, students
        )
    end
end

function _fetch_class_data(class::Class, data::String)
    data_name = join([class.codename_long, data], "-")
    data_names = filter(x->occursin(data_name, x), readdir(@__DIR__))
    data_names_strings = [split(x, "-"; limit=2)[1] for x in data_names]
    data_times_strings = [split(x, "-"; limit=2)[2] for x in data_names]
    data_times = [DateTime(x, ISODateTimeFormat) for x in data_times_strings]
    data_times_sorted = sortperm(data_times)
    data_names_strings = data_names_strings[data_times_sorted]
    data_times = data_times[data_times_sorted]
    return CSV.read(joinpath[@__DIR__, data_names_strings[end]], DataFrame)
end

fetch_class_gradebook(class::Class) = _fetch_class_data(class, "Gradebook")
fetch_class_attendance(class::Class) = _fetch_class_data(class, "Attendance")

abstract type AbstractAssignment end
abstract type Homework <: AbstractAssignment end
abstract type Quiz <: AbstractAssignment end
abstract type Paper <: AbstractAssignment end
abstract type Presentation <: AbstractAssignment end

struct IndividualAssignment{T<:AbstractAssignment}
    name
    value
    due_date
end

struct GroupAssignment{T<:AbstractAssignment}
    name
    value
    due_date
end

struct Gradebook <: AbstractDataFrame
    class::Class
    assignments
    data::DataFrame
end
struct Attendance <: AbstractDataFrame
    class::Class
    assignments
    data::DataFrame
end

@userplot ViewGradebook
@userplot ViewAttendance

@recipe f(::Type{Gradebook}, gb::Gradebook) = gb.data
@recipe f(::Type{Attendance}, att::Attendance) = att.data

end
