module Gradebooks

export MIDNIGHT
export Course, Class
export AbstractAssignmentType, Group, Individual
export AbstractAssignment, AbstractHomework, AbstractExam, AbstractPaper, AbstractPresentation, AbstractProject, AbstractQuiz
export Assignment, Homework, Exam, Paper, Presentation, Project, Quiz
export Submission, Grade
export AbstractGradebook, Gradebook, StudentGradebook, ClassGradebook

using CSV
using DataFrames
using Dates
using Distributed
using Glob
using JSON
using PrettyTables
using Printf

include("preferences.jl")

const MIDNIGHT = Time(23, 59, 59, 999)

include("academictypes.jl")
include("functions.jl")
include("people.jl")

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
            course, section, uppercasefirst(lowercase(semester)), year,
            course.codename, join(["$(course.codename)", "$section_padded", first(uppercase(semester)) * (uppercase(semester)[1:2] == "SU" ? "u" : "") * last("$year", 2)], "-"),
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
const AbstractQuiz = AbstractExam
abstract type AbstrasctAttendance <: AbstractAssignment end
abstract type AbstractAssignmentValueType end
abstract type Points <: AbstractAssignmentValueType end
abstract type Percentage <: AbstractAssignmentValueType end

struct Assignment{T<:AbstractAssignment}
    name::String
    value::UInt64
    due_datetime::DateTime
    class::Class
    Assignment{T}(name, value, due_date, class) where {T<:AbstractAssignment} = new{T}(name, value, fetch_datetime(due_date), class)
end
# Attendance()
Homework(T, name, value, due_date, class) = Assignment{AbstractHomework{T}}(name, value, due_date, class)
Exam(T, name, value, due_date, class) = Assignment{AbstractExam{T}}(name, value, due_date, class)
Paper(T, name, value, due_date, class) = Assignment{AbstractPaper{T}}(name, value, due_date, class)
Presentation(T, name, value, due_date, class) = Assignment{AbstractPresentation{T}}(name, value, due_date, class)
Project(T, name, value, due_date, class) = Assignment{AbstractProject{T}}(name, value, due_date, class)
Quiz(T, name, value, due_date, class) = Assignment{AbstractQuiz{T}}(name, value, due_date, class)

struct Submission{T<:Assignment}
    assignment::T
    submission_datetime::DateTime
    score_points::AbstractFloat
    score_percentage::AbstractFloat
    score_letter::String
    function Submission{T}(assignment, submission_datetime, score) where {T<:Assignment}
        score_percentage = 100(score / assignment.value)
        score_letter = score_letter(score_percentage)
        return new{T}(assignment, submission_datetime, score, score_percentage, score_letter)
    end
end
# Submission{T<:Assignment{<:AbstractAssignment, Group}} = map_students_from_group;

struct Grade{T<:Submission}
    class::Class
    instructor::Instructor
    student::Student
    assignment::Assignment
    submission::T
    Grade{T}(class, instructor, student, submission) where {T<:Submission} = new{T}(class, instructor, student, submission.assignment, submission)
end

abstract type AbstractGradebook <: AbstractDataFrame end
struct Gradebook{T<:Union{Class,Student}} <: AbstractGradebook
    who::T
    # assignments::Vector{Assignment}
    df::DataFrame
    # Gradebook{T}(who, assignments, df) where {T<:Union{Class,Student}} = new{T}(who, assignments, df)
end
# Gradebook{Class}(class::Class, assignments::Vector{Assignment}) = new{Class}(class, assignments, DataFrame(zeros((length(class.roster), length(assignments))), [a.name for a in assignments]))
function Gradebook{Class}(class::Class, assignments)
    names = [a.name for a in assignments]
    if any(isa.(assignments, AbstractAssignment{Group}))
        pushfirst!(names, ["ID", "Preferred", "Last", "Team", "Email"])
    else
        pushfirst!(names, ["ID", "Preferred", "Last", "Email"])
    end
    Gradebook{Class}(class, DataFrame(zeros((length(class.roster), length(names))), names))
end
Gradebook{Student}(student::Student, assignments) = Gradebook{Student}(student, DataFrame(zeros((1, length(assignments))), [a.name for a in assignments]))
const StudentGradebook = Gradebook{Student}
const ClassGradebook = Gradebook{Class}
# const Attendance{T} = Gradebook{T}
# const StudentAttendance = Attendance{Student}
# const ClassAttendance = Attendance{Class}

include("io.jl")
include("plots.jl")
include("reports.jl")

end # end of module
