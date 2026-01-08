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

struct Assignment{T<:AbstractAssignment}
    name::String
    value::Points
    due::DateTime
    # class::Class
    codename::Symbol
    function Assignment{T}(name, value, due_date, codename) where {T<:AbstractAssignment}
        codename = if isa(codename, String)
            articles = ["a", "an", "the"]
            prepositions = ["of", "in", "for", "with", "on", "at", "from", "into", "during", "through", "without", "under", "over", "above", "below", "to"]
            conjuctions = ["for", "and", "nor", "but", "or", "yet", "so"]
            forbidden = vcat(articles, prepositions, conjuctions)
            tokens = filter(s->lowercase(s) .∉ forbidden, split(codename, " "))
            firstword_idx = findfirst(t->isletter(first(t)), tokens)
            reduce(*, filter(!ispunct, first.(tokens[firstword_idx:end])))
        elseif isa(codename, Symbol)
            codename
        else
            @error "`codename` must be of type Symbol or String."
        end
        return new{T}(name, Points(value), parse_datetime(due_date), uppercase2symbol(codename))
    end
end
# Attendance()
Exam(T, name, value, due_date, class) = Assignment{AbstractExam{T}}(name, value, due_date, class)
Homework(T, name, value, due_date, class) = Assignment{AbstractHomework{T}}(name, value, due_date, class)
Paper(T, name, value, due_date, class) = Assignment{AbstractPaper{T}}(name, value, due_date, class)
Presentation(T, name, value, due_date, class) = Assignment{AbstractPresentation{T}}(name, value, due_date, class)
Project(T, name, value, due_date, class) = Assignment{AbstractProject{T}}(name, value, due_date, class)
Quiz(T, name, value, due_date, class) = Assignment{AbstractQuiz{T}}(name, value, due_date, class)

struct Submission{T<:Assignment}
    # assignment::T
    submitted::DateTime
    score::Score
end
# function Submission{T}(assignment, submission_datetime, score) where {T<:Assignment}
#     score_percentage = 100(score / assignment.value)
#     score_letter = score2letter(score_percentage)
#     return new{T}(assignment, submission_datetime, score, score_percentage, score2letter(score_percentage))
# end
# Submission{T<:Assignment{<:AbstractAssignment, Group}} = map_students_from_group;

struct Grade{T<:Assignment}
    # class::Class
    # instructor::Instructor
    student::Student
    # assignment::Assignment
    submission::Submission
end
# Grade{T}(class, instructor, student, submission) where {T<:Submission} = new{T}(class, instructor, student, submission.assignment, submission)
