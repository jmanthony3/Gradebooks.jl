export Score, Submission, Grade, grade
export is_late, late_penalty



using Dates: AbstractDateTime



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
    submitted::Union{DateTime, Dates.CompoundPeriod, Millisecond}
    score::Score
    evaluations::Vector{Evaluation}
    # Submission(assignment, submitted, score) = new(assignment, parse_datetime(submitted), score)
    Submission(submitted, score, evaluations) = new(parse_datetime(submitted), score, evaluations)
end

"Couples student to submitted work for assignment."
struct Grade
    who::Student
    assignment::Assignment
    submission::Submission
end
# function Grade(identifier, roster, assignment, submitted, evaluations::Vector{Evaluation})
#     return Grade(get_student(identifier, roster), assignment, Submission(submitted, Score(assignment, evaluations), evaluations))
# end
# function Grade(identifier, roster, assignment, submitted, marks::Vector{Union{Mark, Credit}})
#     return Grade(identifier, roster, assignment, submitted, map(x->Evaluation(assignment.questions[x[1]], isa(x[2][1], Credit) ? Mark(x[2][1]) : x[2][1]; comment=x[2][2]), enumerate(marks)))
# end

# TODO: honestly, I get a little lost after this point.

function absolute_question_points(q::Question, parent::Point)
    if isa(q.value, Point)
        return q.value
    elseif isa(q.value, Percent)
        return Point(parent.val * q.value.val)
    else
        error("Question values must be Point or Percent, got $(typeof(q.value))")
    end
end

function collect_leaf_weights(q::Question, parent::Point)
    base = absolute_question_points(q, parent)
    if isnothing(q.parts)
        return [(q, base)]
    end
    leaves = Tuple{Question,Point}[]
    for part in q.parts
        append!(leaves, collect_leaf_weights(part, base))
    end
    return leaves
end

function collect_leaf_weights(items::Vector{Question}, parent::Point)
    reduce(vcat, collect_leaf_weights.(items, parent))
end

function distribute_scalar_mark!(evals::Vector{Evaluation}, items::Vector{Question}, mark::Mark, parent::Point)
    leaves = collect_leaf_weights(items, parent)

    if isa(mark.delta, Percent)
        # same fraction of each leaf
        for (leaf, _) in leaves
            push!(evals, Evaluation(leaf, Mark(mark.delta, mark.comment)))
        end
        return
    end

    total = sum(weight.val for (_, weight) in leaves)
    if total == 0.0
        for (leaf, _) in leaves
            push!(evals, Evaluation(leaf, Mark(Point(0.0), mark.comment)))
        end
        return
    end

    for (leaf, weight) in leaves
        share = weight.val / total
        push!(evals, Evaluation(leaf, Mark(Point(mark.delta.val * share), mark.comment)))
    end
end

function _expand!(evals::Vector{Evaluation}, items::Vector{Question}, marks, parent::Point)
    if marks isa Mark || marks isa Real || marks isa Percent
        mark = isa(marks, Mark) ? marks : Mark(marks)
        return distribute_scalar_mark!(evals, items, mark, parent)
    end

    if marks isa AbstractVector
        if length(marks) == length(items)
            for (item, m) in zip(items, marks)
                if !isnothing(item.parts) && m isa AbstractVector
                    _expand!(evals, item.parts, m, absolute_question_points(item, parent))
                else
                    _expand!(evals, [item], m, parent)
                end
            end
            return
        end
        error("Length mismatch between structure and marks")
    end

    error("Unsupported marks type: $(typeof(marks))")
end

function expand_marks(assignment, marks)
    evals = Evaluation[]
    _expand!(evals, assignment.questions, marks, assignment.value)
    return evals
end

"""
    grade(submission::Submission, assignment::Assignment, marks)

Intelligently records evaluations at any level of the assignment tree.
"""
function grade(identifier, roster, assignment, submitted, marks; threshold=STRING_MATCH_THRESHOLD)
    evals = expand_marks(assignment, marks)
    submission = Submission(submitted, Score(assignment, evals), evals)
    return Grade(get_student(identifier, roster; threshold=threshold), assignment, submission)
end

is_late(x::AbstractDateTime) = x > Millisecond(0)
function is_late(a::T, b::T) where {T<:AbstractDateTime}
    # x = canonicalize(a - b)
    # return x >= Millisecond(0.0) ? false : late_penalty(x)
    return is_late(a - b)
end
is_late(x::Submission) = is_late(x.submitted, x.assignment.due)

# Percent(is_late(x) ? (x < Day(7) ? 0.05 : (x < Day(14) ? 0.10 : 1.0)) : 0.0)
late_penalty(x::AbstractDateTime) = error("Late penalty not yet implemented.")
