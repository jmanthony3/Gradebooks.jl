export Question, Rubric
public AssignmentCategory
export Assignment, Attendance, Exam, Homework, Paper, Presentation, Project, Quiz
export isattendance, isexam, ishomework, isother, ispaper, ispresentation, isproject, isquiz
export ExtensionGrant



using Dates: DateTime



"As the leaf in course-assignment tree model, can be nested for questions with parts or rubric categories."
struct Question <: AbstractGradebookNode
    name::String
    value::Credit
    parts::Union{Nothing, Vector{Question}}
    codename::Symbol
    function Question(name, value, parts, codename)
        if !isnothing(parts)
            if any(p->isa(p, Rubric), parts)
                @error "Question parts cannot be of type `Rubric`" parts
                error("Invalid type")
            elseif !(all(p->isa(p.value, Point), parts) || all(p->isa(p.value, Percent), parts))
                @error "Question parts must be of type `Point` or `Percent`" parts
                error("Heterogeneous vector")
            end
            value_p = mapreduce(x->x.value.value, +, parts; init=0.0)
            if isa(first(parts).value, Percent) ? !(isapprox(value_p, 1.0; atol=1e-6)) : (typeof(first(parts).value) == typeof(value) ? (value_p != value.value) : true)
                @warn "Value distribution of question parts does not equal question value" Σp=value_p question=(name, value)
            end
        end
        codename = if isa(codename, Symbol)
            codename
        elseif isa(codename, AbstractString)
            string_2codename(codename)
        else
            error("`codename` must be of type Symbol or AbstractString")
        end
        pieces = isa(parts, Rubric) ? parts.metrics : parts
        # if !isnothing(pieces)
        #     for (i, part) in enumerate(pieces)
        #         pieces[i] = Question(part.name, part.value, part.parts, Symbol(uppercase("$(codename)_$(isa(part.codename, Symbol) ? part.codename : string_2codename(part.codename))")))
        #     end
        # end
        return new(join(map(t->(first(t, 2) == "\\{" && last(t, 2) == "\\}") ? "{$(t[begin+2:end-2])}" : ((first(t) == '{' && last(t) == '}') ? t[begin+1:end-1] : t), split(name, " ")), " "), value, pieces, codename)
    end
end
Question(name, value, parts=nothing) = Question(name, value, parts, name)


"Weight distributions to calculate grade from evaluations."
struct Rubric <: AbstractGradebookNode
    name::String
    metrics::Vector{Question}
    codename::Symbol
    function Rubric(name, metrics, codename)
        if all(x->isa(x.value, Percent), metrics)
            total = mapreduce(x->x.value.value, +, metrics; init=0.0)
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
            string_2codename(codename)
        else
            error("`codename` must be of type Symbol or AbstractString")
        end
        return new(join(map(t->(first(t, 2) == "\\{" && last(t, 2) == "\\}") ? "{$(t[begin+2:end-2])}" : ((first(t) == '{' && last(t) == '}') ? t[begin+1:end-1] : t), split(name, " ")), " "), metrics, codename)
    end
end
Rubric(name::String, metrics::Vector{Question}) = Rubric(name, metrics, name)
Rubric(source::Question, metrics::Vector{Question}) = Rubric(source.name, metrics)


@enum AssignmentCategory begin
    CategoryAttendance
    CategoryExam
    CategoryHomework
    CategoryOther
    CategoryPaper
    CategoryPresentation
    CategoryProject
    CategoryQuiz
end

"""
Is branch in course-assignment tree model always composed of at least one leaf question, even if not given.

`is_group` switches whether assignment should be completed individually.
"""
struct Assignment <: AbstractGradebookNode
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
                mapreduce(x->x.value.value, +, filter(x->isa(x, Question), questions); init=0.0), true
            elseif any(q->isa(q, Rubric), questions)
                mapreduce(x->x.source.value.value, +, filter(x->isa(x, Rubric), questions); init=0.0), false
            end
            if question_or_rubric && any(q->isa(q, Rubric), questions)
                value_q += mapreduce(x->x.source.value.value, +, filter(x->isa(x, Rubric), questions); init=0.0)
            end
            value_first = if question_or_rubric
                first(filter(x->isa(x, Question), questions)).value
            else
                first(filter(x->isa(x, Rubric), questions)).source.value
            end
            if isa(value_first, Percent) ? !(isapprox(value_q, 1.0; atol=1e-6)) : (typeof(value_first) == typeof(value) ? (value_q != value.value) : true)
                @warn "Value distribution of questions does not equal assignment value" Σq=value_q assignment=(name, value)
            end
        end
        codename = if isa(codename, Symbol)
            codename
        elseif isa(codename, AbstractString)
            string_2codename(codename)
        else
            error("`codename` must be of type Symbol or AbstractString")
        end
        return new(join(map(t->(first(t, 2) == "\\{" && last(t, 2) == "\\}") ? "{$(t[begin+2:end-2])}" : ((first(t) == '{' && last(t) == '}') ? t[begin+1:end-1] : t), split(name, " ")), " "), Point(value), parse_datetime(due), category, is_group, questions, codename)
    end
end

"Convenience function constructing `Assignment` to track attendance."
Attendance(     name, value, due, questions=nothing; is_group=false) = Assignment(name, isa(value, Percent) ? (value * COURSE_POINT_SYSTEM) : value, due, CategoryAttendance,    is_group, questions, string_2codename(name))

"Convenience function constructing `Assignment` for an exam."
Exam(           name, value, due, questions=nothing; is_group=false) = Assignment(name, isa(value, Percent) ? (value * COURSE_POINT_SYSTEM) : value, due, CategoryExam,          is_group, questions, string_2codename(name))

"Convenience function constructing `Assignment` for homework."
Homework(       name, value, due, questions=nothing; is_group=false) = Assignment(name, isa(value, Percent) ? (value * COURSE_POINT_SYSTEM) : value, due, CategoryHomework,      is_group, questions, string_2codename(name))

"Convenience function constructing `Assignment` for some other academic item: e.g., extra credit."
Other(          name, value, due, questions=nothing; is_group=false) = Assignment(name, isa(value, Percent) ? (value * COURSE_POINT_SYSTEM) : value, due, CategoryOther,         is_group, questions, string_2codename(name))

"Convenience function constructing `Assignment` for a paper."
Paper(          name, value, due, questions=nothing; is_group=false) = Assignment(name, isa(value, Percent) ? (value * COURSE_POINT_SYSTEM) : value, due, CategoryPaper,         is_group, questions, string_2codename(name))

"Convenience function constructing `Assignment` for a presentation."
Presentation(   name, value, due, questions=nothing; is_group=false) = Assignment(name, isa(value, Percent) ? (value * COURSE_POINT_SYSTEM) : value, due, CategoryPresentation,  is_group, questions, string_2codename(name))

"Convenience function constructing `Assignment` for a project."
Project(        name, value, due, questions=nothing; is_group=false) = Assignment(name, isa(value, Percent) ? (value * COURSE_POINT_SYSTEM) : value, due, CategoryProject,       is_group, questions, string_2codename(name))

"Convenience function constructing `Assignment` for a quiz."
Quiz(           name, value, due, questions=nothing; is_group=false) = Assignment(name, isa(value, Percent) ? (value * COURSE_POINT_SYSTEM) : value, due, CategoryQuiz,          is_group, questions, string_2codename(name))

isattendance(x)                         = false
isattendance(x::AssignmentCategory)     = x == CategoryAttendance
isattendance(x::Assignment)             = isattendance(x.category)
isexam(x)                               = false
isexam(x::AssignmentCategory)           = x == CategoryExam
isexam(x::Assignment)                   = isexam(x.category)
ishomework(x)                           = false
ishomework(x::AssignmentCategory)       = x == CategoryHomework
ishomework(x::Assignment)               = ishomework(x.category)
isother(x)                              = false
isother(x::AssignmentCategory)          = x == CategoryOther
isother(x::Assignment)                  = isother(x.category)
ispaper(x)                              = false
ispaper(x::AssignmentCategory)          = x == CategoryPaper
ispaper(x::Assignment)                  = ispaper(x.category)
ispresentation(x)                       = false
ispresentation(x::AssignmentCategory)   = x == CategoryPresentation
ispresentation(x::Assignment)           = ispresentation(x.category)
isproject(x)                            = false
isproject(x::AssignmentCategory)        = x == CategoryProject
isproject(x::Assignment)                = isproject(x.category)
isquiz(x)                               = false
isquiz(x::AssignmentCategory)           = x == CategoryQuiz
isquiz(x::Assignment)                   = isquiz(x.category)


struct ExtensionGrant
    assignment::Assignment
    due::DateTime
    granted::DateTime
    reason::String
    notes::String
end
