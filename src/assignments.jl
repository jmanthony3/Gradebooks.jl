export AssignmentType, Group, Individual
export AbstractAssignment, AbstractAttendance, AbstractExam, AbstractHomework, AbstractPaper, AbstractPresentation, AbstractProject, AbstractQuiz
export Assignment, Exam, Homework, Paper, Presentation, Project, Quiz
export Submission, Grade

abstract type AbstractAssignment end
abstract type AssignmentType end
abstract type Group <: AssignmentType end
abstract type Individual <: AssignmentType end
abstract type AbstractAttendance <: AbstractAssignment end
abstract type AbstractExam{T<:AssignmentType} <: AbstractAssignment end
abstract type AbstractHomework{T<:AssignmentType} <: AbstractAssignment end
abstract type AbstractPaper{T<:AssignmentType} <: AbstractAssignment end
abstract type AbstractPresentation{T<:AssignmentType} <: AbstractAssignment end
abstract type AbstractProject{T<:AssignmentType} <: AbstractAssignment end
const AbstractQuiz = AbstractExam

struct Assignment{T<:AbstractAssignment, Y<:AssignmentType}
    name::String
    value::Points
    due::DateTime
    # class::Class
    codename::Symbol
    function Assignment{T,Y}(name, value, due_date, codename) where {T<:AbstractAssignment, Y<:AssignmentType}
        codename = if isa(codename, Symbol)
            codename
        elseif isa(codename, String)
            articles = ["a", "an", "the"]
            conjuctions = ["for", "and", "nor", "but", "or", "yet", "so"]
            prepositions = ["of", "in", "for", "with", "on", "at", "from", "into", "during", "through", "without", "under", "over", "above", "below", "to"]
            forbidden = vcat(articles, conjuctions, prepositions)
            tokens = filter(s->lowercase(s) ∉ forbidden, split(filter(!ispunct, codename), " "))
            firstword_idx = findfirst(t->isletter(first(t)), tokens)
            if isnothing(firstword_idx)
                @error "After sanitization, no remaining tokens begin with a letter." codename tokens
            end
            uppercase2symbol(mapreduce(t->isdigit(first(t)) ? t : first(t), *, tokens[firstword_idx:end]))
        else
            @error "`codename` must be of type Symbol or String."
        end
        return new{T,Y}(name, Points(value), parse_datetime(due_date), uppercase2symbol(codename))
    end
end
Attendance(::Type{Y}, name, value, due_date, codename) where {Y<:Individual}        = Assignment{AbstractAttendance, Y}(name, value, due_date, codename)
Exam(::Type{Y}, name, value, due_date, codename) where {Y<:AssignmentType}          = Assignment{AbstractExam, Y}(name, value, due_date, codename)
Homework(::Type{Y}, name, value, due_date, codename) where {Y<:AssignmentType}      = Assignment{AbstractHomework, Y}(name, value, due_date, codename)
Paper(::Type{Y}, name, value, due_date, codename) where {Y<:AssignmentType}         = Assignment{AbstractPaper, Y}(name, value, due_date, codename)
Presentation(::Type{Y}, name, value, due_date, codename) where {Y<:AssignmentType}  = Assignment{AbstractPresentation, Y}(name, value, due_date, codename)
Project(::Type{Y}, name, value, due_date, codename) where {Y<:AssignmentType}       = Assignment{AbstractProject, Y}(name, value, due_date, codename)
Quiz(::Type{Y}, name, value, due_date, codename) where {Y<:AssignmentType}          = Assignment{AbstractQuiz, Y}(name, value, due_date, codename)
Attendance(Y, name, value, due_date)                                                = Attendance(Y, name, value, due_date, name)
Exam(Y, name, value, due_date)                                                      = Exam(Y, name, value, due_date, name)
Homework(Y, name, value, due_date)                                                  = Homework(Y, name, value, due_date, name)
Paper(Y, name, value, due_date)                                                     = Paper(Y, name, value, due_date, name)
Presentation(Y, name, value, due_date)                                              = Presentation(Y, name, value, due_date, name)
Project(Y, name, value, due_date)                                                   = Project(Y, name, value, due_date, name)
Quiz(Y, name, value, due_date)                                                      = Quiz(Y, name, value, due_date, name)

struct Submission # {T<:Assignment}
    assignment::Assignment
    submitted::DateTime
    score::Score
    Submission(assignment, submitted, score) = new(assignment, parse_datetime(submitted), score)
end
# Submission{T<:Assignment{<:AbstractAssignment, Group}} = map_students_from_group;

struct Grade # {T<:Assignment}
    # class::Class
    # instructor::Instructor
    student::Student
    assignment::Assignment
    submission::Submission
end
Grade(student, submission) = Grade(student, submission.assignment, submission)
