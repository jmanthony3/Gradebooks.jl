export Question, Evaluation, Rubric
export Assignment, Attendance, Exam, Homework, Paper, Presentation, Project, Quiz
public AssignmentCategory

using Dates: DateTime

struct Question
    name::String
    value::Credit
    parts::Union{Nothing, Vector{Question}}
    codename::Symbol
    function Question(name, value, parts, codename)
        if !isnothing(parts)
            if any(p->isa(p, Rubric), parts)
                @error "Question parts cannot be of type `Rubric`." parts=parts
            end
            if !(all(p->isa(p.value, Point), parts) || all(p->isa(p.value, Percent), parts))
                @error "Question parts must be of type `Point` or `Percent`." parts=parts
            end
            value_p = mapreduce(x->x.value, +, parts; init=zero(typeof(first(parts).value)))
            if isa(value_p, Percent) ? !(isapprox(value_p.val, 1.0; atol=1e-6)) : (typeof(value_p) == typeof(value) ? (value_p != value) : true)
                @error "Value distribution of question parts does not equal question" Σp=value_p question=(name, value)
            end
        end
        codename = if isa(codename, Symbol)
            codename
        elseif isa(codename, AbstractString)
            sanitize2codify(codename)
        else
            @error "`codename` must be of type Symbol or AbstractString."
        end
        return new(join(map(t->(first(t, 2) == "\\{" && last(t, 2) == "\\}") ? "{$(t[begin+2:end-2])}" : ((first(t) == '{' && last(t) == '}') ? t[begin+1:end-1] : t), split(name, " ")), " "), value, parts, uppercase2symbol(codename))
    end
end
Question(name, value, parts=nothing) = Question(name, value, parts, name)

struct Evaluation
    target::Question
    mark::Mark
    comment::String
    function Evaluation(question, mark, comment)
        if question.parts !== nothing
            @warn "Evaluating question without specifying a part." question=question
        end
        return new(question, mark, comment)
    end
end
Evaluation(question, mark::Credit; comment="") = Evaluation(question, Mark(mark), comment)

struct Rubric
    name::String
    metrics::Vector{Question}
    codename::Symbol
    function Rubric(name, metrics, codename)
        if all(x->isa(x.value, Percent), metrics)
            total = mapreduce(x->x.value.val, +, metrics; init=0.0)
            if !isapprox(total, 1.0; atol=1e-6)
                @error "Rubric metric values must sum to 100%." Σmetrics=total
            end
        end
        codename = if isa(codename, Symbol)
            codename
        elseif isa(codename, AbstractString)
            sanitize2codify(codename)
        else
            @error "`codename` must be of type Symbol or AbstractString."
        end
        return new(join(map(t->(first(t, 2) == "\\{" && last(t, 2) == "\\}") ? "{$(t[begin+2:end-2])}" : ((first(t) == '{' && last(t) == '}') ? t[begin+1:end-1] : t), split(name, " ")), " "), metrics, uppercase2symbol(codename))
    end
end
Rubric(name::String, metrics::Vector{Question}) = Rubric(name, metrics, name)
Rubric(source::Question, metrics::Vector{Question}) = Rubric(source.name, metrics)

@enum AssignmentCategory begin
    attendance
    exam
    homework
    other
    paper
    presentation
    project
    quiz
end

struct Assignment
    name::String
    value::Point
    due::DateTime
    category::AssignmentCategory
    is_group::Bool
    questions::Vector{Question}
    codename::Symbol
    function Assignment(name, value, due, category, is_group, questions, codename)
        if isnothing(questions)
            questions = [Question(name, value)]
        else
            value_q, question_or_rubric = if any(q->isa(q, Question), questions)
                mapreduce(x->x.value, +, filter(x->isa(x, Question), questions); init=zero(typeof(first(filter(x->isa(x, Question), questions)).value))), true
            elseif any(q->isa(q, Rubric), questions)
                mapreduce(x->x.source.value, +, filter(x->isa(x, Rubric), questions); init=zero(typeof(first(filter(x->isa(x, Rubric), questions)).source.value))), false
            end
            if question_or_rubric && any(q->isa(q, Rubric), questions)
                value_q += mapreduce(x->x.source.value, +, filter(x->isa(x, Rubric), questions); init=zero(typeof(first(filter(x->isa(x, Rubric), questions)).source.value)))
            end
            if isa(value_q, Percent) ? !(isapprox(value_q.val, 1.0; atol=1e-6)) : (typeof(value_q) == typeof(value) ? (value_q != value) : true)
                @error "Value distribution of questions does not equal assignment" Σq=value_q assignment=(name, value)
            end
        end
        codename = if isa(codename, Symbol)
            codename
        elseif isa(codename, AbstractString)
            sanitize2codify(codename)
        else
            @error "`codename` must be of type Symbol or AbstractString."
        end
        return new(join(map(t->(first(t, 2) == "\\{" && last(t, 2) == "\\}") ? "{$(t[begin+2:end-2])}" : ((first(t) == '{' && last(t) == '}') ? t[begin+1:end-1] : t), split(name, " ")), " "), Point(value), parse_datetime(due), category, is_group, questions, uppercase2symbol(codename))
    end
end
Attendance(     name, value, due, questions=nothing; is_group=false) = Assignment(name, isa(value, Percent) ? (value * COURSE_POINTSCALE) : value, due, attendance,    is_group, questions, sanitize2codify(name))
Exam(           name, value, due, questions=nothing; is_group=false) = Assignment(name, isa(value, Percent) ? (value * COURSE_POINTSCALE) : value, due, exam,          is_group, questions, sanitize2codify(name))
Homework(       name, value, due, questions=nothing; is_group=false) = Assignment(name, isa(value, Percent) ? (value * COURSE_POINTSCALE) : value, due, homework,      is_group, questions, sanitize2codify(name))
Other(          name, value, due, questions=nothing; is_group=false) = Assignment(name, isa(value, Percent) ? (value * COURSE_POINTSCALE) : value, due, other,         is_group, questions, sanitize2codify(name))
Paper(          name, value, due, questions=nothing; is_group=false) = Assignment(name, isa(value, Percent) ? (value * COURSE_POINTSCALE) : value, due, paper,         is_group, questions, sanitize2codify(name))
Presentation(   name, value, due, questions=nothing; is_group=false) = Assignment(name, isa(value, Percent) ? (value * COURSE_POINTSCALE) : value, due, presentation,  is_group, questions, sanitize2codify(name))
Project(        name, value, due, questions=nothing; is_group=false) = Assignment(name, isa(value, Percent) ? (value * COURSE_POINTSCALE) : value, due, project,       is_group, questions, sanitize2codify(name))
Quiz(           name, value, due, questions=nothing; is_group=false) = Assignment(name, isa(value, Percent) ? (value * COURSE_POINTSCALE) : value, due, quiz,          is_group, questions, sanitize2codify(name))
