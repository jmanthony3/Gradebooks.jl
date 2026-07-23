export Evaluation, Score, score, Submission, Grade, grade, islate, latepenalty



using Dates: AbstractDateTime



"Couples target question with redline mark."
struct Evaluation <: AbstractGradebookNode
    target::Question
    mark::Mark
    path::LeafPath
    comment::String

    function Evaluation(question, mark, path, comment)
        if question.parts !== nothing
            @warn "Evaluating question without specifying a part" question
        end
        return new(question, mark, path, comment)
    end
end
Evaluation(question, mark::Mark, path=Symbol[]; comment="") = Evaluation(question, mark, LeafPath(path), comment)
Evaluation(question, mark::Credit, path=Symbol[]; comment="") = Evaluation(question, Mark(mark), LeafPath(path), comment)

"Compares `earned` points to `value` with `percent` and letter grade."
struct Score <: AbstractGradebookNode
    earned::Point
    value::Point
    comment::String
end
Score(percentage::Percent, value::Point; comment="") = Score(percentage*value, value, comment)
Score(points::T, value::T; comment="") where {T<:Point} = Score(points, value, comment)
Score(points::T, value::T; comment="") where {T<:Real} = Score(Point.([points, value])..., comment)

function Base.getproperty(s::Score, sym::Symbol)
    if sym == :percent
        return getfield(s, :earned) / getfield(s, :value)
    elseif sym == :letter
        return credit2lettergrade(getfield(s, :earned) / getfield(s, :value))
    else
        return getfield(s, sym)
    end
end

Base.propertynames(s::Score) = (:earned, :value, :percent, :letter, :comment)

"Resolves evaluations to total points earned which may be calculated from percent earned against assignment part value."
function score(assignment::Assignment, evaluations::Vector{Evaluation})
    points = 0.0
    for (path, leaf, parent_value, current_value) ∈ rake_leaves(assignment; parent_value=assignment.value)
        score = leaf_score(path, leaf, evaluations, parent_value, current_value; display_credits="point")
        points += score.value
    end
    return Score(Point(points), assignment.value, join(filter(!isnothing, map(x->x.comment, evaluations)), "\n"))
end


"Couples datetime stamp of submitted work to computed score from evaluations."
struct Submission <: AbstractGradebookNode
    submitted::AbstractDateTime
    score::Score
    evaluations::Vector{Evaluation}
    Submission(submitted, score, evaluations) = new(parse_datetime(submitted), score, evaluations)
end


"Couples student to submitted work for assignment."
struct Grade <: AbstractGradebookNode
    student::Student
    assignment::Assignment
    submission::Submission
end


isattendance(x::Grade)     = isattendance(x.assignment)
isexam(x::Grade)           = isexam(x.assignment)
ishomework(x::Grade)       = ishomework(x.assignment)
isother(x::Grade)          = isother(x.assignment)
ispaper(x::Grade)          = ispaper(x.assignment)
ispresentation(x::Grade)   = ispresentation(x.assignment)
isproject(x::Grade)        = isproject(x.assignment)
isquiz(x::Grade)           = isquiz(x.assignment)


function normalize_mark(raw)
    if raw isa Tuple
        if length(raw) == 0
            return Mark(Point(0.0)), ""
        elseif length(raw) >= 2
            value, comment = raw[1], raw[2]
            return if value isa Mark
                value, string(comment)
            else
                Mark(value), string(comment)
            end
        else
            return normalize_mark(raw[1])
        end
    elseif raw isa Mark
        return raw, ""
    else
        return Mark(raw), ""
    end
end

function resolve_branch_value(node, parent_value)
    if parent_value === nothing
        return nothing
    end

    if !hasproperty(node, :value)
        return parent_value
    end

    value = getproperty(node, :value)

    if isa(value, Point)
        return value
    elseif isa(value, Percent)
        if isa(parent_value, Point)
            return Point(parent_value.value * value.value)
        elseif isa(parent_value, Percent)
            return Percent(parent_value.value * value.value)
        else
            return parent_value
        end
    end

    return parent_value
end

function resolve_leaf_point_value(node, parent_value)
    resolved = resolve_branch_value(node, parent_value)

    if isa(resolved, Point)
        return resolved
    elseif isa(resolved, Percent)
        return Point(resolved.value)
    else
        return Point(0.0)
    end
end

function resolve_point_value(node, parent_value::Point)
    return resolve_leaf_point_value(node, parent_value)
end

function resolve_point_value(node, parent_value::Percent)
    return resolve_leaf_point_value(node, parent_value)
end

function trace_leaf_resolution(node, parent_value; prefix=())
    path = LeafPath(node; prefix=prefix)
    resolved = resolve_leaf_point_value(node, parent_value)
    return (
        path = path,
        node_value = hasproperty(node, :value) ? getproperty(node, :value) : nothing,
        parent_value = parent_value,
        resolved_value = resolved
    )
end

function get_leafvalue(leaf, nodevalue::Point)
    if isa(leaf.value, Point)
        return leaf.value
    elseif isa(leaf.value, Percent)
        return Point(nodevalue.value * leaf.value.value)
    elseif isnothing(leaf.value)
        return nodevalue
    else
        error("Leaf values must be of type `Point` or `Percent`, got leaf=$(typeof(leaf.value))")
    end
end

function get_leaves(node::Question, nodevalue::Point)
    base = get_leafvalue(node, nodevalue)
    return if isnothing(node.parts)
        [(node, base)]
    else
        leaves = Tuple{Question, Point}[]
        append!(leaves, [get_leaves(part, base) for part ∈ node.parts]...)
        leaves
    end
end

function get_leaves(node::Vector{Question}, nodevalue::Point)
    reduce(vcat, [get_leaves(leaf, nodevalue) for leaf ∈ node])
end

function get_leaves(node::Rubric, nodevalue::Point)
    return [(metric, get_leafvalue(metric, nodevalue)) for metric ∈ node.metrics]
end

function distribute_scalar_mark!(evaluations::Vector{Evaluation}, items, mark::Mark, nodevalue::Point, prefix=())
    leaves = get_leaves(items, nodevalue)
    if isa(mark.delta, Percent)
        # same fraction of each leaf
        for (leaf, _) ∈ leaves
            push!(evaluations, Evaluation(leaf, mark, LeafPath(tuple(prefix..., leaf.codename)), mark.comment))
        end
    else
        total = sum(weight.value for (_, weight) ∈ leaves)
        if total == 0.0
            for (leaf, _) ∈ leaves
                push!(evaluations, Evaluation(leaf, Mark(Point(0.0)), LeafPath(tuple(prefix..., leaf.codename)), mark.comment))
            end
        else
            for (leaf, weight) ∈ leaves
                share = weight.value / total
                leaf_points = Point(mark.delta.value * share)
                push!(evaluations, Evaluation(leaf, Mark(leaf_points), LeafPath(tuple(prefix..., leaf.codename)), mark.comment))
            end
        end
    end
    return nothing
end

"Recursively applies marks down to the leaves of the appropriate branch."
function expand!(evaluations::Vector{Evaluation}, items, marks, nodevalue::Point, prefix=())
    if marks isa Mark || marks isa Point || marks isa Percent || marks isa Real || marks isa Tuple
        mark, comment = normalize_mark(marks)
        return distribute_scalar_mark!(evaluations, items, mark, nodevalue, prefix)
    elseif marks isa AbstractVector || marks isa Tuple
        if length(marks) == length(items)
            for (item, mark) ∈ zip(items, marks)
                child_prefix = tuple(prefix..., item.codename)
                if !isnothing(children(item)) && !isempty(children(item))
                    expand!(evaluations, children(item), mark, get_leafvalue(item, nodevalue), child_prefix)
                else
                    mark_obj, comment = normalize_mark(mark)
                    if isa(item, Question)
                        push!(evaluations, Evaluation(item, mark_obj, LeafPath(child_prefix), comment))
                    elseif isa(item, Rubric)
                        for metric ∈ item.metrics
                            metric_path = tuple(child_prefix..., metric.codename)
                            metric_mark, metric_comment = normalize_mark(mark)
                            push!(evaluations, Evaluation(metric, metric_mark, LeafPath(metric_path), metric_comment))
                        end
                    end
                end
            end
            return nothing
        else
            error("Length mismatch between structure and marks")
        end
    else
        error("Unsupported marks type: $(typeof(marks))")
    end
end

"Magically applies evaluations at any level of the course-assignment tree."
function grade(identifier, roster, assignment, submitted, marks; threshold=STRING_MATCH_THRESHOLD)
    evaluations = Evaluation[]
    expand!(evaluations, assignment.questions, marks, Point(assignment.value), (assignment.codename,))
    submission = Submission(submitted, score(assignment, evaluations), evaluations)
    return Grade(get_student(identifier, roster; threshold=threshold), assignment, submission)
end


"Helper function to determine whether submission was before assignment due date."
islate(x::Millisecond) = x > Millisecond(0)
islate(a::Submission, y::Assignment) = islate(a.submitted - y.due)
islate(x::Grade) = islate(x.submission, x.assignment)


"""
    latepenalty(x)::Bool

Convenience function calling `is_late` and returning appropriate deductions for if late.

Will throw error if called and left unimplemented.

## Example
Say the institutional policy for deductions of student work submitted late is as follows:
* 10% deduction if submitted within one week of due date
* 20% deduction if submitted within two weeks of due date
* 100% deduction if submitted two weeks or later of due date

Then this could be implemented by overwriting the `Gradebooks.late_penaly(x::Millisecond)` method:
```
julia> using Gradebooks
julia> Gradebooks.latepenalty(x::Millisecond) = Percent(is_late(x) ? (x < Day(7) ? 0.10 : (x < Day(14) ? 0.20 : 1.0)) : 0.0)
julia> latepenalty(Dates.CompoundPeriod(Day(1), Hour(12), Minute(36), Second(25)))
10%
julia> latepenalty(Dates.CompoundPeriod(Week(1), Day(1), Hour(12), Minute(36), Second(25)))
20%
julia> latepenalty(Dates.CompoundPeriod(Week(2), Day(1), Hour(12), Minute(36), Second(25)))
100%
julia> latepenalty(-Dates.CompoundPeriod(Week(1), Day(1), Hour(12), Minute(36), Second(25)))
0%
```
"""
latepenalty(x::Millisecond)::Percent = error("Late penalty not yet implemented for `Millisecond`")
latepenalty(a::Submission, y::Assignment) = latepenalty(a.submitted - y.due)
latepenalty(x::Grade) = latepenalty(x.submission, x.assignment)
