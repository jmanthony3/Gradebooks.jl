export Question, Evaluation, Rubric
export Assignment, Attendance, Exam, Homework, Paper, Presentation, Project, Quiz
public AssignmentCategory



using Dates: DateTime



"As the leaf in course-assignment tree model, can be nested for questions with parts or rubric categories."
struct Question
    name::String
    value::Credit
    parts::Union{Nothing, Vector{Question}}
    codename::Symbol
    function Question(name, value, parts, codename)
        if !isnothing(parts)
            if any(p->isa(p, Rubric), parts)
                @error "Question parts cannot be of type `Rubric`" parts
                error("Invalid type")
            end
            if !(all(p->isa(p.value, Point), parts) || all(p->isa(p.value, Percent), parts))
                @error "Question parts must be of type `Point` or `Percent`" parts
                error("Heterogeneous vector")
            end
            value_p = mapreduce(x->x.value, +, parts; init=zero(typeof(first(parts).value)))
            if isa(value_p, Percent) ? !(isapprox(value_p.val, 1.0; atol=1e-6)) : (typeof(value_p) == typeof(value) ? (value_p != value) : true)
                @warn "Value distribution of question parts does not equal question value" Σp=value_p question=(name, value)
            end
        end
        codename = if isa(codename, Symbol)
            codename
        elseif isa(codename, AbstractString)
            string_sanitize(string_2codename(codename))
        else
            error("`codename` must be of type Symbol or AbstractString")
        end
        return new(join(map(t->(first(t, 2) == "\\{" && last(t, 2) == "\\}") ? "{$(t[begin+2:end-2])}" : ((first(t) == '{' && last(t) == '}') ? t[begin+1:end-1] : t), split(name, " ")), " "), value, parts, string_2uppercase_symbol(codename))
    end
end
Question(name, value, parts=nothing) = Question(name, value, parts, name)

"Couples target question with redline mark."
struct Evaluation
    target::Question
    mark::Mark
    comment::String
    function Evaluation(question, mark, comment)
        if question.parts !== nothing
            @warn "Evaluating question without specifying a part" question
        end
        return new(question, mark, comment)
    end
end
Evaluation(question, mark::Credit; comment="") = Evaluation(question, Mark(mark), comment)

"Weight distributions to calculate grade from evaluations."
struct Rubric
    name::String
    metrics::Vector{Question}
    codename::Symbol
    function Rubric(name, metrics, codename)
        if all(x->isa(x.value, Percent), metrics)
            total = mapreduce(x->x.value.val, +, metrics; init=0.0)
            if !isapprox(total, 1.0; atol=1e-6)
                @warn "Rubric metric values do not sum to 100%" Σmetrics=100total
            end
        else
            @error "Rubric metrics must be of type `Percent`" metrics
            error("Heterogeneous vector")
        end
        codename = if isa(codename, Symbol)
            codename
        elseif isa(codename, AbstractString)
            string_sanitize(string_2codename(codename))
        else
            error("`codename` must be of type Symbol or AbstractString")
        end
        return new(join(map(t->(first(t, 2) == "\\{" && last(t, 2) == "\\}") ? "{$(t[begin+2:end-2])}" : ((first(t) == '{' && last(t) == '}') ? t[begin+1:end-1] : t), split(name, " ")), " "), metrics, string_2uppercase_symbol(codename))
    end
end
Rubric(name::String, metrics::Vector{Question}) = Rubric(name, metrics, name)
Rubric(source::Question, metrics::Vector{Question}) = Rubric(source.name, metrics)

@enum AssignmentCategory begin
    Category_Attendance
    Category_Exam
    Category_Homework
    Category_Other
    Category_Paper
    Category_Presentation
    Category_Project
    Category_Quiz
end

"""

Is branch in course-assignment tree model always composed of at least one leaf question, even if not given.

`is_group` switches whether assignment should be completed individually.
"""
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
                @warn "Value distribution of questions does not equal assignment value" Σq=value_q assignment=(name, value)
            end
        end
        codename = if isa(codename, Symbol)
            codename
        elseif isa(codename, AbstractString)
            string_sanitize(string_2codename(codename))
        else
            error("`codename` must be of type Symbol or AbstractString")
        end
        return new(join(map(t->(first(t, 2) == "\\{" && last(t, 2) == "\\}") ? "{$(t[begin+2:end-2])}" : ((first(t) == '{' && last(t) == '}') ? t[begin+1:end-1] : t), split(name, " ")), " "), Point(value), parse_datetime(due), category, is_group, questions, string_2uppercase_symbol(codename))
    end
end

"Convenience function constructing `Assignment` to track attendance."
Attendance(     name, value, due, questions=nothing; is_group=false) = Assignment(name, isa(value, Percent) ? (value * COURSE_POINT_SYSTEM) : value, due, Category_Attendance,    is_group, questions, string_sanitize(string_2codename(name)))

"Convenience function constructing `Assignment` for an exam."
Exam(           name, value, due, questions=nothing; is_group=false) = Assignment(name, isa(value, Percent) ? (value * COURSE_POINT_SYSTEM) : value, due, Category_Exam,          is_group, questions, string_sanitize(string_2codename(name)))

"Convenience function constructing `Assignment` for homework."
Homework(       name, value, due, questions=nothing; is_group=false) = Assignment(name, isa(value, Percent) ? (value * COURSE_POINT_SYSTEM) : value, due, Category_Homework,      is_group, questions, string_sanitize(string_2codename(name)))

"Convenience function constructing `Assignment` for some other academic item: e.g., extra credit."
Other(          name, value, due, questions=nothing; is_group=false) = Assignment(name, isa(value, Percent) ? (value * COURSE_POINT_SYSTEM) : value, due, Category_Other,         is_group, questions, string_sanitize(string_2codename(name)))

"Convenience function constructing `Assignment` for a paper."
Paper(          name, value, due, questions=nothing; is_group=false) = Assignment(name, isa(value, Percent) ? (value * COURSE_POINT_SYSTEM) : value, due, Category_Paper,         is_group, questions, string_sanitize(string_2codename(name)))

"Convenience function constructing `Assignment` for a presentation."
Presentation(   name, value, due, questions=nothing; is_group=false) = Assignment(name, isa(value, Percent) ? (value * COURSE_POINT_SYSTEM) : value, due, Category_Presentation,  is_group, questions, string_sanitize(string_2codename(name)))

"Convenience function constructing `Assignment` for a project."
Project(        name, value, due, questions=nothing; is_group=false) = Assignment(name, isa(value, Percent) ? (value * COURSE_POINT_SYSTEM) : value, due, Category_Project,       is_group, questions, string_sanitize(string_2codename(name)))

"Convenience function constructing `Assignment` for a quiz."
Quiz(           name, value, due, questions=nothing; is_group=false) = Assignment(name, isa(value, Percent) ? (value * COURSE_POINT_SYSTEM) : value, due, Category_Quiz,          is_group, questions, string_sanitize(string_2codename(name)))
