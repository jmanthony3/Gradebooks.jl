export Evaluation, Score, Submission, Grade, grade
export islate, latepenalty



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
# Evaluation(question, mark::Mark, path::LeafPath=LeafPath(); comment="") = Evaluation(question, mark, path, comment)
# Evaluation(question, mark::Credit, path::LeafPath=LeafPath(); comment="") = Evaluation(question, Mark(mark), path, comment)

"Compares `earned` points to `value` with `percent` and letter grade."
struct Score <: AbstractGradebookNode
    earned::Point
    value::Point
    percent::Percent
    letter::LetterGrade
    comment::String
end
Score(percentage::Percent, value::Point; comment="") = Score(percentage*value, value, percentage, credit2lettergrade(percentage), comment)
Score(points::T, value::T; comment="") where {T<:Point} = Score(points, value, Percent(points.value / value.value; normalized=false), credit2lettergrade(Percent(points.value / value.value; normalized=false)), comment)
Score(points::T, value::T; comment="") where {T<:Real} = ((p, v) = Point.([points, value]); Score(p, v, Percent(p.value / v.value; normalized=false), credit2lettergrade(Percent(p.value / v.value; normalized=false)), comment))

# # Score(assignment::Assignment, tallies::Vararg{Tally{T,M,V}}) where {T<:AbstractScore,M<:AbstractMark,V<:AbstractScore} = Score(assignment.value, tally(tallies...)) # mapreduce(tally, +, [tallies...]))
# # Score(assignment::Assignment, tallies::Vector{<:Tally}; comment="") = Score(mapreduce(tally, +, filter(!isempty, map(y->filter(x->isa(x.mark, y), tallies), [Grant, Subtract]))), assignment.value; comment=comment)
# Score(assignment::Assignment, tallies::Vector{<:Evaluation}; comment="") = Score(only(tally(tallies)), assignment.value; comment=comment)
# Score(assignment::Assignment, tallies::Vararg{<:Evaluation}; comment="") = Score(assignment, collect(tallies); comment=comment)
# # function tally(assignment::Assignment, tallies::Vector{<:Union{<:AbstractMark, Tuple{<:AbstractMark, String}}})
# Score(assignment::Assignment, marks::Vector{<:Mark}; comment="") = Score(assignment, map(x->Evaluation(assignment.questions[x[1]], x[2]), enumerate(marks)); comment=comment)
# function Score(assignment::Assignment, marks::Vector{Union{<:Mark,<:Vector{<:Mark}}}; comment="")
#     score = Score(Point(0.0), zero(typeof(assignment.value)); comment=comment)
#     score_f(x) = mapreduce(z->Score(tally(map(i->Evaluation(assignment.questions[x][i], marks[x][i]), z)), mapreduce(i->assignment.questions[x][i].value, +, z); comment=comment), +, map(y->findall(typeof.(marks[x]) .== y), union(typeof.(marks[x]))))
#     score_g(x) = mapreduce(z->Score(tally(z[1]), z[2]; comment=comment), +, zip(map(i->map(y->Evaluation(y[1], y[2]), zip(assignment.questions[i].metrics, marks[i])), x), mapreduce(i->assignment.questions[i].source.value, +, x)))
#     score_h(x) = mapreduce(score_g, +, map(y->x[findall(typeof.(marks[x]) .== y)], union(typeof.(marks[x]))))
#     marks_idx = findall(x->isa(x, Mark), marks)
#     vectormarks_idx = findall(x->isa(x, Vector{<:Mark}), marks)
#     if !isempty(marks_idx)
#         score += score_f(marks_idx)
#     end
#     if !isempty(vectormarks_idx)
#         score += score_h(vectormarks_idx)
#     end
#     return score
# end
# function Score(assignment::Assignment, marks::Vector{Any}; comment="")
#     try
#         return Score(assignment, Vector{Union{<:Mark,<:Vector{<:Mark}}}(marks))
#     catch e
#         @error e
#     end
# end

# function Score(item::Assignment, mark::Union{Mark, Credit}; comment="")
#     question = if length(item.questions) == 1
#         item.questions[1]
#     else
#         @warn "Evaluating entire assignment without specifying a question." item=item
#         Question(item.name, item.value)
#     end
#     return Score(item, Evaluation(question, isa(mark, Credit) ? Mark(mark) : mark, comment))
# end
"Resolves evaluations to total points earned which may be calculated from percent earned against assignment part value."
function Score(assignment::Assignment, evaluations::Vector{Evaluation})
    # earned = zero(Point)
    # for evaluation in evaluations
    #     delta = evaluation.mark.delta
    #     if isa(delta, Point)
    #         earned += delta
    #     elseif isa(delta, Percent)
    #         if isa(evaluation.target, Question)
    #             if isa(evaluation.target.value, Point)
    #                 earned += delta * evaluation.target.value
    #             elseif isa(evaluation.target.value, Percent)
    #                 earned += delta * evaluation.target.value * assignment.value
    #             else
    #                 @error "Question values must be of type `Point` or `Percent`" question=evaluation.target
    #                 error("Unsupported type")
    #             end
    #         elseif isa(evaluation.target, Rubric)
    #             for metric in evaluation.target.metrics
    #                 if isa(metric.value, Point)
    #                     earned += delta * metric.value
    #                 elseif isa(metric.value, Percent)
    #                     try
    #                         earned += delta * metric.value * assignment.value
    #                     catch
    #                         @error "Unclear how combination resolves to points" assignment=assignment target=evaluation.target mark=evaluation.mark metric=metric
    #                         error("Ambiguous evaluation")
    #                     end
    #                 else
    #                     @error "Rubric metrics must be of type `Point` or `Percent`" metric
    #                     error("Unsupported type")
    #                 end
    #             end
    #         end
    #     else
    #         @error "Mark must be of type `Point` or `Percent`" typeof(delta)
    #         error("Unsupported type")
    #     end
    # end
    # percent = Percent(earned.value / assignment.value.value; normalized=false)
    # return Score(earned, assignment.value, percent, credit2lettergrade(percent), join(map(x->x.comment, evaluations), "\n"))
    flat_leaves = flatten_leaves(assignment; parent_value=assignment.value)
    # all_leaves = [leaf for (_, leaf, _, _) in flat_leaves]
    # total_values = map(g -> total_for_grade(g, flat_leaves, assignment; display_credits=display_credits), grades)
    points = 0.0
    for (path, leaf, parent_value, current_value) in flat_leaves
        score = leaf_score(path, leaf, evaluations, parent_value, current_value; display_credits="point")
        points += score.value
    end
    percent = Percent(points / assignment.value.value; normalized=false)
    return Score(Point(points), assignment.value, percent, credit2lettergrade(percent), join(filter(!isnothing, map(x->x.comment, evaluations)), "\n"))
end


"Couples datetime stamp of submitted work to computed score from evaluations."
struct Submission <: AbstractGradebookNode
    submitted::AbstractDateTime
    score::Score
    evaluations::Vector{Evaluation}
    # Submission(assignment, submitted, score) = new(assignment, parse_datetime(submitted), score)
    Submission(submitted, score, evaluations) = new(parse_datetime(submitted), score, evaluations)
end


"Couples student to submitted work for assignment."
struct Grade <: AbstractGradebookNode
    student::Student
    assignment::Assignment
    submission::Submission
end
# function Grade(identifier, roster, assignment, submitted, evaluations::Vector{Evaluation})
#     return Grade(get_student(identifier, roster), assignment, Submission(submitted, Score(assignment, evaluations), evaluations))
# end
# function Grade(identifier, roster, assignment, submitted, marks::Vector{Union{Mark, Credit}})
#     return Grade(identifier, roster, assignment, submitted, map(x->Evaluation(assignment.questions[x[1]], isa(x[2][1], Credit) ? Mark(x[2][1]) : x[2][1]; comment=x[2][2]), enumerate(marks)))
# end


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
    path = leaf_path(node; prefix=prefix)
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
        append!(leaves, [get_leaves(part, base) for part in node.parts]...)
        leaves
    end
end

function get_leaves(node::Vector{Question}, nodevalue::Point)
    reduce(vcat, [get_leaves(leaf, nodevalue) for leaf in node])
end

function get_leaves(node::Rubric, nodevalue::Point)
    return [(metric, get_leafvalue(metric, nodevalue)) for metric in node.metrics]
end

function distribute_scalar_mark!(evaluations::Vector{Evaluation}, items, mark::Mark, nodevalue::Point, prefix=())
    leaves = get_leaves(items, nodevalue)
    if isa(mark.delta, Percent)
        # same fraction of each leaf
        for (leaf, _) in leaves
            push!(evaluations, Evaluation(leaf, mark, LeafPath(tuple(prefix..., leaf.codename)), mark.comment))
        end
    else
        total = sum(weight.value for (_, weight) in leaves)
        if total == 0.0
            for (leaf, _) in leaves
                push!(evaluations, Evaluation(leaf, Mark(Point(0.0)), LeafPath(tuple(prefix..., leaf.codename)), mark.comment))
            end
        else
            for (leaf, weight) in leaves
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
            for (item, mark) in zip(items, marks)
                child_prefix = tuple(prefix..., item.codename)
                if !isnothing(children(item)) && !isempty(children(item))
                    expand!(evaluations, children(item), mark, get_leafvalue(item, nodevalue), child_prefix)
                else
                    mark_obj, comment = normalize_mark(mark)
                    if isa(item, Question)
                        push!(evaluations, Evaluation(item, mark_obj, LeafPath(child_prefix), comment))
                    elseif isa(item, Rubric)
                        for metric in item.metrics
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
    submission = Submission(submitted, Score(assignment, evaluations), evaluations)
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
