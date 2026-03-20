export string2codename
export AssignmentType, Group, Individual
export AbstractAssignment, AbstractAttendance, AbstractExam, AbstractHomework, AbstractPaper, AbstractPresentation, AbstractProject, AbstractQuiz
export Assignment, Attendance, Exam, Homework, Paper, Presentation, Project, Quiz
export Submission, Grade
export islate, late_penalty


abstract type AbstractAssignment end
abstract type AssignmentType end
abstract type Group <: AssignmentType end
abstract type Individual <: AssignmentType end
abstract type AbstractAttendance{T<:Individual} <: AbstractAssignment end
abstract type AbstractExam{T<:AssignmentType} <: AbstractAssignment end
abstract type AbstractHomework{T<:AssignmentType} <: AbstractAssignment end
abstract type AbstractPaper{T<:AssignmentType} <: AbstractAssignment end
abstract type AbstractPresentation{T<:AssignmentType} <: AbstractAssignment end
abstract type AbstractProject{T<:AssignmentType} <: AbstractAssignment end
abstract type AbstractQuiz{T<:AssignmentType} <: AbstractAssignment end

function string2codename(s)
    articles = ["a", "an", "the"]
    conjuctions = ["for", "and", "nor", "but", "or", "yet", "so"]
    prepositions = ["of", "in", "for", "with", "on", "at", "from", "into", "during", "through", "without", "under", "over", "above", "below", "to"]
    forbidden = vcat(articles, conjuctions, prepositions)
    tokens = filter(!isempty, filter(s->lowercase(s) ∉ forbidden, split(filter(cn->!ispunct(cn) || cn ∈ ['{', '}'], s), " ")))
    firstword_idx = findfirst(t->(first(t) == '{' ? true : isletter(first(t))), tokens)
    if isnothing(firstword_idx)
        @error "After sanitization, no remaining tokens begin with a letter." s tokens
    end
    return uppercase2symbol(mapreduce(t->(first(t) == '{' && last(t) == '}') ? t[begin+1:end-1] : (isdigit(first(t)) ? t : first(filter(!ispunct, t))), *, tokens[firstword_idx:end]))
end

struct Assignment{T<:AbstractAssignment, Y<:AssignmentType}
    name::String
    value::Points
    due::DateTime
    questions::Vector{Union{Question,Rubric}}
    # class::Class
    codename::Symbol
    function Assignment{T,Y}(name, value, due_date, questions, codename) where {T<:AbstractAssignment, Y<:AssignmentType}
        value_q, question_or_rubric = if any(q->isa(q, Question), questions)
            mapreduce(x->x.value, +, filter(x->isa(x, Question), questions); init=zero(typeof(first(questions).value))), true
        elseif any(q->isa(q, Rubric), questions)
            mapreduce(x->x.source.value, +, filter(x->isa(x, Rubric), questions); init=zero(typeof(first(questions).value))), false
        end
        if question_or_rubric && any(q->isa(q, Rubric), questions)
            value_q += mapreduce(x->x.source.value, +, filter(x->isa(x, Rubric), questions); init=zero(typeof(first(questions).value)))
        end
        if isa(value_q, Percentage) ? value_q != Percentage(1.0) : (typeof(value_q) == typeof(value) ? (value_q != value) : true)
            @error "Value distribution of questions does not equal assignment" Σq=value_q assignment=(name, value)
        end
        codename = if isa(codename, Symbol)
            codename
        elseif isa(codename, String)
            string2codename(codename)
        else
            @error "`codename` must be of type Symbol or String."
        end
        return new{T,Y}(join(map(t->(first(t, 2) == "\\{" && last(t, 2) == "\\}") ? "{$(t[begin+2:end-2])}" : ((first(t) == '{' && last(t) == '}') ? t[begin+1:end-1] : t), split(name, " ")), " "), Points(value), parse_datetime(due_date), questions, uppercase2symbol(codename))
    end
end
Attendance(::Type{Y}, name, value, due_date, questions, codename) where {Y<:Individual}         = Assignment{AbstractAttendance, Y}(name, value, due_date, questions, codename)
Exam(::Type{Y}, name, value, due_date, questions, codename) where {Y<:AssignmentType}           = Assignment{AbstractExam, Y}(name, value, due_date, questions, codename)
Homework(::Type{Y}, name, value, due_date, questions, codename) where {Y<:AssignmentType}       = Assignment{AbstractHomework, Y}(name, value, due_date, questions, codename)
Paper(::Type{Y}, name, value, due_date, questions, codename) where {Y<:AssignmentType}          = Assignment{AbstractPaper, Y}(name, value, due_date, questions, codename)
Presentation(::Type{Y}, name, value, due_date, questions, codename) where {Y<:AssignmentType}   = Assignment{AbstractPresentation, Y}(name, value, due_date, questions, codename)
Project(::Type{Y}, name, value, due_date, questions, codename) where {Y<:AssignmentType}        = Assignment{AbstractProject, Y}(name, value, due_date, questions, codename)
Quiz(::Type{Y}, name, value, due_date, questions, codename) where {Y<:AssignmentType}           = Assignment{AbstractQuiz, Y}(name, value, due_date, questions, codename)
Attendance(Y, name, value, due_date, questions)                                                 = Attendance(Y, name, value, due_date, questions, name)
Exam(Y, name, value, due_date, questions)                                                       = Exam(Y, name, value, due_date, questions, name)
Homework(Y, name, value, due_date, questions)                                                   = Homework(Y, name, value, due_date, questions, name)
Paper(Y, name, value, due_date, questions)                                                      = Paper(Y, name, value, due_date, questions, name)
Presentation(Y, name, value, due_date, questions)                                               = Presentation(Y, name, value, due_date, questions, name)
Project(Y, name, value, due_date, questions)                                                    = Project(Y, name, value, due_date, questions, name)
Quiz(Y, name, value, due_date, questions)                                                       = Quiz(Y, name, value, due_date, questions, name)

# Score(assignment::Assignment, tallies::Vararg{Tally{T,M,V}}) where {T<:AbstractScore,M<:AbstractMark,V<:AbstractScore} = Score(assignment.value, tally(tallies...)) # mapreduce(tally, +, [tallies...]))
# Score(assignment::Assignment, tallies::Vector{<:Tally}; comment="") = Score(mapreduce(tally, +, filter(!isempty, map(y->filter(x->isa(x.mark, y), tallies), [Grant, Subtract]))), assignment.value; comment=comment)
Score(assignment::Assignment, tallies::Vector{<:Tally}; comment="") = Score(tally(tallies), assignment.value; comment=comment)
Score(assignment::Assignment, tallies::Vararg{<:Tally}; comment="") = Score(assignment, collect(tallies); comment=comment)
# function tally(assignment::Assignment, tallies::Vector{<:Union{<:AbstractMark, Tuple{<:AbstractMark, String}}})
Score(assignment::Assignment, marks::Vector{<:AbstractMark}; comment="") = Score(assignment, map(x->Tally(assignment.questions[x[1]], x[2]), enumerate(marks)); comment=comment)
function Score(assignment::Assignment, marks::Vector{Union{<:AbstractMark,<:Vector{<:AbstractMark}}}; comment="")
    score = Score(Points(0.0), zero(typeof(assignment.value)); comment=comment)
    score_f(x) = mapreduce(z->Score(tally(map(i->Tally(assignment.questions[x][i], marks[x][i]), z)), mapreduce(i->assignment.questions[x][i].value, +, z); comment=comment), +, map(y->findall(typeof.(marks[x]) .== y), union(typeof.(marks[x]))))
    score_g(x) = mapreduce(z->Score(tally(z[1]), z[2]; comment=comment), +, zip(map(i->map(y->Tally(y[1], y[2]), zip(assignment.questions[i].metrics, marks[i])), x), mapreduce(i->assignment.questions[i].source.value, +, x)))
    score_h(x) = mapreduce(score_g, +, map(y->x[findall(typeof.(marks[x]) .== y)], union(typeof.(marks[x]))))
    marks_idx = findall(x->isa(x, AbstractMark), marks)
    vectormarks_idx = findall(x->isa(x, Vector{<:AbstractMark}), marks)
    if !isempty(marks_idx)
        score += score_f(marks_idx)
    end
    if !isempty(vectormarks_idx)
        score += score_h(vectormarks_idx)
    end
    return score
end
function Score(assignment::Assignment, marks::Vector{Any}; comment="")
    try
        return Score(assignment, Vector{Union{<:AbstractMark,<:Vector{<:AbstractMark}}}(marks))
    catch e
        @error e
    end
end


struct Submission # {T<:Assignment}
    # assignment::Assignment
    submitted::Union{DateTime, Dates.CompoundPeriod, Millisecond}
    score::Score
    tallies::Vector{Tally}
    # Submission(assignment, submitted, score) = new(assignment, parse_datetime(submitted), score)
    Submission(submitted, score, tallies) = new(parse_datetime(submitted), score, tallies)
end


struct Grade # {T<:Assignment}
    # class::Class
    # instructor::Instructor
    student::Student
    assignment::Assignment
    submission::Submission
end
# Grade(student, submission) = Grade(student, submission.assignment, submission)
Grade(student, assignment::Assignment, submitted, tallies::Vararg{Tally{T,M,V}}) where {T<:AbstractScore,M<:AbstractMark,V<:AbstractScore} = Grade(student, assignment, Submission(submitted, Score(assignment.value, map(tally, tallies))), collect(tallies))


islate(x::Millisecond) = x > Millisecond(0)
islate(x::Dates.CompoundPeriod) = x > Millisecond(0)
function islate(a::T, b::T) where {T<:DateTime}
    # x = canonicalize(a - b)
    # return x >= Millisecond(0.0) ? false : late_penalty(x)
    return islate(a - b)
end
islate(x::Submission) = islate(x.submitted, x.assignment.due)

late_penalty(x::Millisecond) = Percentage(x < Day(7) ? 0.05 : (x < Day(14) ? 0.10 : 1.0))
late_penalty(x::Dates.CompoundPeriod) = Percentage(x < Day(7) ? 0.05 : (x < Day(14) ? 0.10 : 1.0))
