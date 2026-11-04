export Question, Rubric
# public AssignmentCategory
export Assignment, Attendance, Exam, Homework, Other, Paper, Presentation, Project, Quiz
export isattendance, isexam, ishomework, isother, ispaper, ispresentation, isproject, isquiz
export get_assignment
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
            string2codename(codename)
        else
            error("`codename` must be of type Symbol or AbstractString")
        end
        pieces = isa(parts, Rubric) ? parts.metrics : parts
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
            string2codename(codename)
        else
            error("`codename` must be of type Symbol or AbstractString")
        end
        return new(join(map(t->(first(t, 2) == "\\{" && last(t, 2) == "\\}") ? "{$(t[begin+2:end-2])}" : ((first(t) == '{' && last(t) == '}') ? t[begin+1:end-1] : t), split(name, " ")), " "), metrics, codename)
    end
end
Rubric(name::String, metrics::Vector{Question}) = Rubric(name, metrics, name)
Rubric(source::Question, metrics::Vector{Question}) = Rubric(source.name, metrics)


@enum AssignmentCategory begin
    Attendance_Assignment
    Exam_Assignment
    Homework_Assignment
    Other_Assignment
    Paper_Assignment
    Presentation_Assignment
    Project_Assignment
    Quiz_Assignment
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
            string2codename(codename)
        else
            error("`codename` must be of type Symbol or AbstractString")
        end
        return new(join(map(t->(first(t, 2) == "\\{" && last(t, 2) == "\\}") ? "{$(t[begin+2:end-2])}" : ((first(t) == '{' && last(t) == '}') ? t[begin+1:end-1] : t), split(name, " ")), " "), Point(value), parse_datetime(due), category, is_group, questions, codename)
    end
end

const CATEGORY = Dict(lowercase(replace(string(c), "_Assignment" => "")) => c
                      for c in instances(AssignmentCategory))

"""
    make_assignment(name, value, due, category; questions=nothing, is_group=false, codename=nothing)

The only place assignment values, codenames, due times and child trees are normalized.
"""
function make_assignment(name, value::Credit, due, category::AssignmentCategory;
                         questions=nothing, is_group=false, codename=nothing)
    v  = value isa Percent ? Point(value.value * COURSE_POINT_SYSTEM) : value
    cn = string2codename(something(codename, name))
    qs = normalize_children(questions, v)      # ensures ≥1 leaf and checks that values add up
    return Assignment(name, v, parse_datetime(due), category, is_group, qs, cn)
end

for (f, c) in ((:Exam, Exam_Assignment), (:Homework, Homework_Assignment), #= … =#)
    @eval $f(name, value, due, questions=nothing; kw...) =
        make_assignment(name, value, due, $c; questions, kw...)
end

isattendance(x)                         = false
isattendance(x::AssignmentCategory)     = x == Attendance_Assignment
isattendance(x::Assignment)             = isattendance(x.category)
isexam(x)                               = false
isexam(x::AssignmentCategory)           = x == Exam_Assignment
isexam(x::Assignment)                   = isexam(x.category)
ishomework(x)                           = false
ishomework(x::AssignmentCategory)       = x == Homework_Assignment
ishomework(x::Assignment)               = ishomework(x.category)
isother(x)                              = false
isother(x::AssignmentCategory)          = x == Other_Assignment
isother(x::Assignment)                  = isother(x.category)
ispaper(x)                              = false
ispaper(x::AssignmentCategory)          = x == Paper_Assignment
ispaper(x::Assignment)                  = ispaper(x.category)
ispresentation(x)                       = false
ispresentation(x::AssignmentCategory)   = x == Presentation_Assignment
ispresentation(x::Assignment)           = ispresentation(x.category)
isproject(x)                            = false
isproject(x::AssignmentCategory)        = x == Project_Assignment
isproject(x::Assignment)                = isproject(x.category)
isquiz(x)                               = false
isquiz(x::AssignmentCategory)           = x == Quiz_Assignment
isquiz(x::Assignment)                   = isquiz(x.category)


function assignment_candidates(a::Assignment)
    parts = String[
        string(a.codename),
        a.name,
    ]
    return unique(filter(!isempty, map(string_sanitize, parts)))
end

get_assignment(id, v::Vector{Assignment}; kw...) = lookup(id, v, assignment_candidates; what="assignment", kw...)


struct ExtensionGrant
    student_id::String; assignment::Symbol          # codename, not a copied Assignment
    due::DateTime; granted::DateTime
    reason::Symbol                                   # :odas, :athletics, :medical, …
    waive_penalty::Bool; notes::String
end

effective_due(gb, s, a) = something(latest_extension(gb, s, a), a).due
penalty(gb, g::Grade)   = gb.policy(g.submission.submitted - effective_due(gb, g.student, g.assignment))

function grant_extension!(gb, student, assignment; due, reason=:other, notes="", granted=now())
    # due may be a DateTime or a Period offset from the original due date
    push!(gb.extensions, …)
    repost!(gb, student, assignment)                 # recompute the penalty if already graded
end
