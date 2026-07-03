export Evaluation, Score, Submission, Grade, grade
export is_late, late_penalty



using Dates: AbstractDateTime



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
Evaluation(question, mark::Mark; comment="") = Evaluation(question, mark, comment)
Evaluation(question, mark::Credit; comment="") = Evaluation(question, Mark(mark), comment)

"Compares `earned` points to `value` with `percent` and letter grade."
struct Score
    earned::Point
    value::Point
    percent::Percent
    letter::LetterGrade
    comment::String
end
Score(percentage::Percent, value::Point; comment="") = Score(percentage*value, value, percentage, credit2lettergrade(percentage), comment)
Score(points::T, value::T; comment="") where {T<:Real} = ((p, v) = Point.([points, value]); Score(p, v, p/v, credit2lettergrade(p/v), comment))
Score(points::T, value::T; comment="") where {T<:Point} = Score(points, value, points/value, credit2lettergrade(points/value), comment)

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
    earned = zero(Point)
    for evaluation in evaluations
        delta = evaluation.mark.delta
        if isa(delta, Point)
            earned += delta
        elseif isa(delta, Percent)
            if isa(evaluation.target, Question)
                if isa(evaluation.target.value, Point)
                    earned += delta * evaluation.target.value
                elseif isa(evaluation.target.value, Percent)
                    earned += delta * evaluation.target.value * assignment.value
                else
                    @error "Question values must be of type `Point` or `Percent`" question=evaluation.target
                    error("Unsupported type")
                end
            elseif isa(evaluation.target, Rubric)
                for metric in evaluation.target.metrics
                    if isa(metric.value, Point)
                        earned += delta * metric.value
                    elseif isa(metric.value, Percent)
                        try
                            earned += delta * metric.value * assignment.value
                        catch
                            @error "Unclear how combination resolves to points" assignment=assignment target=evaluation.target mark=evaluation.mark metric=metric
                            error("Ambiguous evaluation")
                        end
                    else
                        @error "Rubric metrics must be of type `Point` or `Percent`" metric
                        error("Unsupported type")
                    end
                end
            end
        else
            @error "Mark must be of type `Point` or `Percent`" typeof(delta)
            error("Unsupported type")
        end
    end
    percent = earned / assignment.value
    return Score(earned, assignment.value, percent, credit2lettergrade(percent), join(map(x->x.comment, evaluations), "\n"))
end


"Couples datetime stamp of submitted work to computed score from evaluations."
struct Submission
    submitted::AbstractDateTime
    score::Score
    evaluations::Vector{Evaluation}
    # Submission(assignment, submitted, score) = new(assignment, parse_datetime(submitted), score)
    Submission(submitted, score, evaluations) = new(parse_datetime(submitted), score, evaluations)
end


"Couples student to submitted work for assignment."
struct Grade
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


function get_leafvalue(leaf::Question, nodevalue::Point)
    if isa(leaf.value, Point)
        return leaf.value
    elseif isa(leaf.value, Percent)
        return Point(nodevalue.value * leaf.value.value)
    else
        error("Question values must be of type `Point` or `Percent`, got leaf=$(typeof(leaf.value))")
    end
end

function get_leaves(leaf::Question, nodevalue::Point)
    base = get_leafvalue(leaf, nodevalue)
    return if isnothing(leaf.parts)
        [(leaf, base)]
    else
        leaves = Tuple{Question, Point}[]
        append!(leaves, [get_leaves(part, base) for part in leaf.parts]...)
        leaves
    end
end

function get_leaves(leaves::Vector{Question}, nodevalue::Point)
    reduce(vcat, [get_leaves(leaf, nodevalue) for leaf in leaves])
end

function distribute_scalar_mark!(evaluations::Vector{Evaluation}, items::Vector{Question}, mark::Mark, nodevalue::Point)
    leaves = get_leaves(items, nodevalue)
    if isa(mark.delta, Percent)
        # same fraction of each leaf
        for (leaf, _) in leaves
            push!(evaluations, Evaluation(leaf, mark))
        end
    else
        total = sum(weight.value for (_, weight) in leaves)
        if total == 0.0
            for (leaf, _) in leaves
                push!(evaluations, Evaluation(leaf, Mark(Point(0.0), mark.comment)))
            end
        else
            for (leaf, weight) in leaves
                share = weight.value / total
                push!(evaluations, Evaluation(leaf, Mark(Point(mark.delta * share), mark.comment)))
            end
        end
    end
    return nothing
end

"Recursively applies marks down to the leaves of the appropriate branch."
function expand!(evaluations::Vector{Evaluation}, items::Vector{Question}, marks, nodevalue::Point)
    if marks isa Mark || marks isa Point || marks isa Percent || marks isa Real
        mark = isa(marks, Mark) ? marks : Mark(marks)
        return distribute_scalar_mark!(evaluations, items, mark, nodevalue)
    elseif marks isa AbstractVector
        if length(marks) == length(items)
            for (item, mark) in zip(items, marks)
                if !isnothing(item.parts) && mark isa AbstractVector
                    expand!(evaluations, item.parts, mark, get_leafvalue(item, nodevalue))
                else
                    expand!(evaluations, [item], mark, nodevalue)
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
    expand!(evaluations, assignment.questions, marks, Point(assignment.value))
    submission = Submission(submitted, Score(assignment, evaluations), evaluations)
    return Grade(get_student(identifier, roster; threshold=threshold), assignment, submission)
end


"Helper function to determine whether submission was before assignment due date."
is_late(x::Millisecond) = x > Millisecond(0)
is_late(a::Submission, y::Assignment) = is_late(a.submitted - y.due)
is_late(x::Grade) = is_late(x.submission, x.assignment)


"""
    late_penalty(x)::Bool

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
julia> Gradebooks.late_penalty(x::Millisecond) = Percent(is_late(x) ? (x < Day(7) ? 0.10 : (x < Day(14) ? 0.20 : 1.0)) : 0.0)
julia> late_penalty(Dates.CompoundPeriod(Day(1), Hour(12), Minute(36), Second(25)))
10%
julia> late_penalty(Dates.CompoundPeriod(Week(1), Day(1), Hour(12), Minute(36), Second(25)))
20%
julia> late_penalty(Dates.CompoundPeriod(Week(2), Day(1), Hour(12), Minute(36), Second(25)))
100%
julia> late_penalty(-Dates.CompoundPeriod(Week(1), Day(1), Hour(12), Minute(36), Second(25)))
0%
```
"""
late_penalty(x::Millisecond)::Percent = error("Late penalty not yet implemented for `Millisecond`")
late_penalty(a::Submission, y::Assignment) = late_penalty(a.submitted - y.due)
late_penalty(x::Grade) = late_penalty(x.submission, x.assignment)
