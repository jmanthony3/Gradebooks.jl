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

const MIDNIGHT = Time(23, 59, 59, 999)

function datetime(d)
    if isa(d, DateTime)
        return d
    elseif isa(d, Date)
        d = if year(d) == 1
            Date(year(now()), month(d), day(d))
        else
            d
        end
        return DateTime(d, MIDNIGHT)
    elseif isa(d, String)
        try
            return DateTime(d, ISODateTimeFormat)
        catch
            try
                return DateTime(Date(DateTime(d, ISODateFormat)), MIDNIGHT)
            catch
                try
                    d = first(filter(!isnothing, map(s->DateTime(d, s), [
                        dateformat"yyyy-mm-ddTH:M:S.s",
                        dateformat"yyyy-mm-ddTH:M",
                        dateformat"yyyymmddTH:M",
                        dateformat"yymmddTH:M",
                        dateformat"yyyymmddTHM",
                        dateformat"yymmddTHM",
                        dateformat"yyyymmddTI:Mp",
                        dateformat"yymmddTI:Mp",
                        dateformat"yyyymmddTIMp",
                        dateformat"yymmddTIMp",
                        dateformat"yyyy-mm-dd H:M:S.s",
                        dateformat"yyyy-mm-dd H:M",
                        dateformat"yyyymmdd H:M",
                        dateformat"yymmdd H:M",
                        dateformat"yyyymmdd HM",
                        dateformat"yymmdd HM",
                        dateformat"yyyymmdd I:M p",
                        dateformat"yymmdd I:M p",
                        dateformat"yyyymmdd IM p",
                        dateformat"yymmdd IM p",
                        dateformat"yyyymmdd I:Mp",
                        dateformat"yymmdd I:Mp",
                        dateformat"yyyymmdd IMp",
                        dateformat"yymmdd IMp",
                        dateformat"yyyy-mm-dd",
                        dateformat"y-m-d",
                        dateformat"yyyymmdd",
                        dateformat"yymmdd",
                        dateformat"ymd",
                        dateformat"m/d/yyyy H:M:S.s",
                        dateformat"m/d/yyyy H:M",
                        dateformat"m/d/y H:M",
                        dateformat"m/d H:M",
                        dateformat"m/d/yyyy HM",
                        dateformat"m/d/y HM",
                        dateformat"m/d HM",
                        dateformat"m/d/yyyy I:M p",
                        dateformat"m/d/y I:M p",
                        dateformat"m/d I:M p",
                        dateformat"m/d/yyyy IM p",
                        dateformat"m/d/y IM p",
                        dateformat"m/d IM p",
                        dateformat"m/d/yyyy I:Mp",
                        dateformat"m/d/y I:Mp",
                        dateformat"m/d I:Mp",
                        dateformat"m/d/yyyy IMp",
                        dateformat"m/d/y IMp",
                        dateformat"m/d IMp",
                        dateformat"m/d",
                        dateformat"U d, y H:M",
                        dateformat"U d, y I:M p",
                        dateformat"U d, y I:Mp",
                        dateformat"U d H:M",
                        dateformat"U d I:M p",
                        dateformat"U d I:Mp",
                        dateformat"U d",
                        dateformat"u. d, y H:M",
                        dateformat"u. d, y I:M p",
                        dateformat"u. d, y I:Mp",
                        dateformat"u. d H:M",
                        dateformat"u. d I:M p",
                        dateformat"u. d I:Mp",
                        dateformat"u. d",
                        dateformat"u. d",
                        dateformat"u. d",
                        dateformat"u d, y H:M",
                        dateformat"u d, y I:M p",
                        dateformat"u d, y I:Mp",
                        dateformat"u d H:M",
                        dateformat"u d I:M p",
                        dateformat"u d I:Mp",
                        dateformat"u d",
                        dateformat"u d",
                        dateformat"u d",
                    ])))
                    d = if Dates.value(Time(d)) == 0
                        DateTime(d, MIDNIGHT)
                    else
                        d
                    end
                    return if year(d) == 1
                        DateTime(Date(year(now()), month(d), day(d)), Time(d))
                    else
                        d
                    end
                catch
                    @error "I could not parse the datetime..." d
                end
            end
        end
    else
        @info "Must be `DateTime` or `String` but is" typeof(d)
        @error "I could not parse the datetime..." d
    end
end

abstract type AbstractPerson end

name(firstname, lastname; title="", suffix="") = (title == "" ? "" : "$title ") * join([firstname, lastname]) * (suffix == "" ? "" : ", $suffix")
codename(firstname, lastname) = uppercase(join(map(s->first(s, 1), [firstname, lastname])))

struct Instructor <: AbstractPerson
    firstname
    lastname
    title
    suffix
    id
    email
    phone
    name
    codename
    job_title
    Instructor(firstname, lastname; title="", suffix="", initials="", id="", email="", phone="", job_title="") = new(firstname, lastname, title, suffix, id, email, phone, name(firstname, lastname; title=title, suffix=suffix), isempty(initials) ? codename(firstname, lastname) : initials, job_title)
end

struct Student <: AbstractPerson
    firstname
    lastname
    title
    suffix
    id
    email
    phone
    name
    codename
    discipline
    Student(firstname, lastname; title="", suffix="", initials="", id="", email="", phone="", discipline="") = new(firstname, lastname, title, suffix, id, email, phone, name(firstname, lastname; title=title, suffix=suffix), isempty(initials) ? codename(firstname, lastname) : initials, discipline)
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

abstract type AbstractAssignment end
abstract type AbstractAssignmentType end
struct Group <: AbstractAssignmentType end
struct Individual <: AbstractAssignmentType end
abstract type AbstractHomework{T<:AbstractAssignmentType} <: AbstractAssignment end
abstract type AbstractExam{T<:AbstractAssignmentType} <: AbstractAssignment end
abstract type AbstractPaper{T<:AbstractAssignmentType} <: AbstractAssignment end
abstract type AbstractPresentation{T<:AbstractAssignmentType} <: AbstractAssignment end
abstract type AbstractProject{T<:AbstractAssignmentType} <: AbstractAssignment end
const AbstractQuiz{T<:AbstractAssignmentType} = AbstractExam{T<:AbstractAssignmentType}
abstract type AbstrasctAttendance <: AbstractAssignment end
abstract type AbstractAssignmentValueType end
abstract type Points <: AbstractAssignmentValueType end
abstract type Percentage <: AbstractAssignmentValueType end

struct Assignment{T<:AbstractAssignment}
    name::String
    value::UInt64
    due_datetime::DateTime
    Assignment{T}(name, value, due_date) where {T<:AbstractAssignment} = new{T}(name, value, fetch_datetime(due_date))
end
# Attendance()
Homework(T, name, value, due_date) = Assignment{AbstractHomework{T}}(name, value, due_date)
Exam(T, name, value, due_date) = Assignment{AbstractExam{T}}(name, value, due_date)
Paper(T, name, value, due_date) = Assignment{AbstractPaper{T}}(name, value, due_date)
Presentation(T, name, value, due_date) = Assignment{AbstractPresentation{T}}(name, value, due_date)
Project(T, name, value, due_date) = Assignment{AbstractProject{T}}(name, value, due_date)
Quiz(T, name, value, due_date) = Assignment{AbstractQuiz{T}}(name, value, due_date)

struct Submission{T<:Assignment}
    assignment::T
    score::AbstractFloat
    submission_datetime::DateTime
    # Submission{T}(assignment, score, submission_datetime) where {T<:Assignment} = new{T}(assignment, score, submission_datetime)
end
# Submission{T<:Assignment{<:AbstractAssignment, Group}} = map_students_from_group;
struct Grade{T<:Submission}
    student::Student
    assignment::Assignment
    score::AbstractFloat
    submission_datetime::DateTime
    Grade{T}(student, submission) where {T<:Submission} = new{T}(student, submission.assignment, submission.score, submission.submission_datetime)
end

abstract type AbstractGradebook <: AbstractDataFrame end
struct Gradebook{T<:Union{Class,Student}} <: AbstractGradebook
    who::T
    assignments::Vector{Assignment}
    df::DataFrame
    Gradebook{T}(who, assignments, df) where {T<:Union{Class,Student}} = new{T}(who, assignments, df)
end
Gradebook(class::Class, assignments::Vector{Assignment}) = Gradebook{Class}(class, assignments, DataFrame(zeros((length(class.roster)+1, length(assignments)+1)), push!([a.name for a in assignments], "Total")))
const StudentGradebook = Gradebook{Student}
const ClassGradebook = Gradebook{Class}
# const Attendance{T} = Gradebook{T}
# const StudentAttendance = Attendance{Student}
# const ClassAttendance = Attendance{Class}

function _fetch_class_data(class::Class, data::String)
    data_name = join([class.codename_long, data], "-")
    data_names = filter(x->occursin(data_name, x), readdir(@__DIR__))
    data_names_strings = [split(x, "-"; limit=2)[1] for x in data_names]
    data_times_strings = [split(x, "-"; limit=2)[2] for x in data_names]
    data_times = [DateTime(x, ISODateTimeFormat) for x in data_times_strings]
    data_times_sorted = sortperm(data_times)
    data_names_strings = data_names_strings[data_times_sorted]
    data_times = data_times[data_times_sorted]
    df = CSV.read(joinpath[@__DIR__, data_names_strings[end]], DataFrame)
    return Gradebook{Class}(class, names(df), df)
end

fetch_class_gradebook(class::Class) = _fetch_class_data(class, "Gradebook")
# fetch_class_attendance(class::Class) = _fetch_class_data(class, "Attendance")

@userplot ViewGradebook
# @userplot ViewAttendance

@recipe f(::Type{Gradebook}, gb::Gradebook) = gb.df

end
