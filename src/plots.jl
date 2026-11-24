export view_gradebook, view_assignment, view_assignment_trends, view_attendance, view_major_distribution, view_attendance_tree_ring



using DataFrames
using Distributions
using PrettyTables
using Colors
using ColorSchemes
using Plots



numeric_value(x::Real) = Float64(x)
numeric_value(x::Credit) = Float64(x.value)
numeric_value(x::LetterGrade) = Float64(x.quality_points)
numeric_value(x::Grade) = Float64(x.submission.score.earned)
numeric_value(x::AttendanceStatus) = ispresent(x) ? 1 : (isexcused(x) ? 0.66 : (islate(x) || istardy(x) ? 0.33 : (isabsent(x) ? 0 : NaN)))
numeric_value(x::AttendanceRecord) = numeric_value(x.status)
numeric_value(x) = NaN

function column_bounds(df::DataFrame, j::Int)
    vals = filter(!isnan, map(numeric_value, df[:, j]))
    return isempty(vals) ? (0.0, 1.0) : (minimum(vals), maximum(vals))
end

function color_for_value(_, data, i, j)
    v = data[i, j]
    nv = numeric_value(v)
    lo, hi = column_bounds(data, j)
    c = if isnan(nv)
        "#ffffff"
    elseif lo == hi
        "#" * hex(get(colorschemes[:RdYlGn], 1))
    else
        s = clamp((nv - lo) / (hi - lo), 0, 1)
        "#" * hex(get(colorschemes[:RdYlGn], s))
    end
    return ["background-color" => c]
end

function color_for_value_invert(_, data, i, j)
    v = data[i, j]
    nv = numeric_value(v)
    lo, hi = column_bounds(data, j)
    c = if isnan(nv)
        "#ffffff"
    elseif lo == hi
        "#" * hex(get(colorschemes[:RdYlGn], 1))
    else
        s = 1 - clamp((nv - lo) / (hi - lo), 0, 1)
        "#" * hex(get(colorschemes[:RdYlGn], s))
    end
    return ["background-color" => c]
end

function per_column_highlighters(df::DataFrame; invert_cols=Set{String}())
    df_names = names(df)
    hls = HtmlHighlighter[]
    for j ∈ 1:ncol(df)
        push!(hls, HtmlHighlighter(
            (data, i, jj) -> jj == j,
            (df_names[j] ∈ invert_cols) ? color_for_value_invert : color_for_value
        ))
    end
    return hls
end

function render_table(
    df::DataFrame;
    title="",
    subtitle="",
    output_path="",
    column_labels=nothing,
    row_labels=nothing,
    summary_row_labels=nothing,
    summary_rows=nothing,
    invert_cols=Set{String}(),
    style=nothing
)
    p = PrettyTable(
        df;
        title=title,
        subtitle=subtitle,
        column_labels=column_labels,
        row_labels=row_labels,
        summary_row_labels=summary_row_labels,
        summary_rows=summary_rows,
        highlighters=per_column_highlighters(df; invert_cols=invert_cols),
        style=!isnothing(style) ? style : HtmlTableStyle(),
        backend=:html,
        stand_alone=true
    )

    mkpath(dirname(output_path))
    open(output_path, "w") do io
        write(io, repr(p))
    end

    return p.data
end

function resolve_display_value(earned::Point, item, parent_value; display_credits=DISPLAY_CREDITS)
    leaf_value = resolve_leaf_point_value(item, parent_value)

    if display_credits == "point"
        return earned
    elseif display_credits == "percent"
        return Percent(earned.value / leaf_value.value; normalize=false)
    elseif display_credits == "auto"
        if isa(item.value, Percent)
            return Percent(earned.value / leaf_value.value; normalize=false)
        else
            return earned
        end
    else
        return earned
    end
end

function leaf_score(path, item, evs, parent_value, current_value; display_credits=DISPLAY_CREDITS)
    idx = findfirst(e -> e.path == path, evs)
    earned = if isnothing(idx)
        Point(0.0)
    else
        ev = evs[idx]
        δ = ev.mark.delta
        if isa(δ, Point)
            δ
        elseif isa(δ, Percent)
            Point(current_value.value * δ.value)
        else
            Point(0.0)
        end
    end
    return resolve_display_value(earned, item, parent_value; display_credits=display_credits)
end

function total_for_grade(g, flat_leaves, assignment; display_credits=DISPLAY_CREDITS)
    points = 0.0
    for (path, leaf, parent_value, current_value) ∈ flat_leaves
        score = leaf_score(path, leaf, g.submission.evaluations, parent_value, current_value; display_credits="point")
        points += score.value
    end

    return if display_credits == "percent"
        Percent(points / assignment.value.value; normalize=false)
    else
        Point(points)
    end
end

function build_assignment_display(gb::Gradebook, grades::Vector{Grade}, assignment::Assignment; filter_students=isactive, teams=Team[], display_credits=DISPLAY_CREDITS)
    students_idx = if !isnothing(filter_students)
        sort(if isa(filter_students, Vector{Int})
            filter_students
        elseif isa(filter_students, Roster)
            map(s->gb.class.roster.by_id[s.person.id], filter_students.students)
        elseif isa(filter_students, Vector{Student})
            map(s->gb.class.roster.by_id[s.person.id], filter_students)
        elseif isa(filter_students, Vector{String})
            sort(filter(!isnothing, map(s->try
                gb.class.roster.by_id[get_student(s, gb.class.roster).person.id]
            catch
                nothing
            end, filter_students)))
        else
            error("Could not insert student filter which must be provided as roster or vector of integers, students, or string identifiers")
        end)
    else
        (1:nrow(gb.total))
    end
    grades = grades[students_idx]
    # collect all leaf nodes once, with a unique display codename
    flat_leaves = rake_leaves(assignment; parent_value=assignment.value)
    all_leaves = [leaf for (_, leaf, _, _) ∈ flat_leaves]

    total_values = map(i->isassigned(grades, i) ? (display_credits == "percent" ? grades[i].submission.score.percent : grades[i].submission.score.earned) : NaN, 1:length(grades))

    df = DataFrame(
        Total = total_values,
        Percent = map(total_values) do t
            if isa(t, Percent)
                t
            elseif isa(t, Point)
                Percent(t.value / assignment.value.value; normalize=false)
            else
                NaN
            end
        end,
        Letter = map(total_values) do t
            if isa(t, Percent)
                credit2lettergrade(t)
            elseif isa(t, Point)
                credit2lettergrade(t, assignment.value)
            else
                NaN
            end
        end,
        Missing = map(total_values) do t
            if isa(t, Percent)
                Point(assignment.value.value * (1 - t.value))
            elseif isa(t, Point)
                Point(assignment.value.value - t.value)
            else
                NaN
            end
        end
    )

    # add one column per leaf using the prefixed display codename
    for (i, (path, leaf, parent_value, current_value)) ∈ enumerate(flat_leaves)
        codename = Symbol(join(path.parts, "."))
        insertcols!(df, i, codename => map(i->isassigned(grades, i) ? leaf_score(path, leaf, grades[i].submission.evaluations, parent_value, current_value; display_credits=display_credits) : missing, 1:length(grades)))
    end

    column_labels = [
        names(df),
        # map(x->repr(x.category)[20:end], all_leaves),
        # map(x->x.is_group ? "Group" : "Individual", all_leaves),
        vcat(display_credits == "auto" ? map(x->repr(typeof(x.value)), all_leaves) : fill(display_credits == "percent" ? "Percent" : "Point", length(all_leaves)), fill("", 4)),
    ]

    data = [
        map(s->!isempty(s.person.name_preferred) ? s.person.name_preferred : s.person.name_given, gb.class.roster.students[students_idx]), # Preferred
        map(s->s.person.name_family, gb.class.roster.students[students_idx]), # Last
        map(s->s.person.id, gb.class.roster.students[students_idx]), # ID
        map(s->s.person.email, gb.class.roster.students[students_idx]), # Email
    ]
    if !isempty(gb.class.teams)
        team_names = String[]
        for student ∈ gb.class.roster.students[students_idx]
            found = false
            for team ∈ gb.class.teams
                if any(t -> t.person.id == student.person.id, team.roster.students)
                    push!(team_names, team.name)
                    found = true
                    break
                end
            end
            if !found
                push!(team_names, "")
            end
        end
    end

    return df, all_leaves, column_labels, [join(collect(row), " ") for row ∈ zip(data...)]
end

function sanitize_value(x)
    try
        return ismissing(x) || x === nothing ? missing : x
    catch
        return missing
    end
end

function sanitize_column(col)
    T = Union{Missing, eltype(col)}
    out = Vector{T}(undef, length(col))
    for i in eachindex(col)
        out[i] = try
            sanitize_value(col[i])
        catch
            missing
        end
    end
    return out
end

function sanitize_dataframe(df::DataFrame)
    out = DataFrame()
    for name in names(df)
        out[!, name] = sanitize_column(df[!, name])
    end
    return out
end

function build_gradebook_display(gb::Gradebook;
    filter_assignments=nothing,
    viewing_attendance=false,
    filter_students=isactive,
    display_credits=DISPLAY_CREDITS
)
    assignments = get_assignments(gb; filter_assignments=filter_assignments, viewing_attendance=viewing_attendance)
    students_idx = get_students(gb; filter_students=filter_students)

    safe_raw = sanitize_dataframe(gb.raw)
    safe_penalty = sanitize_dataframe(gb.penalty)
    safe_total = sanitize_dataframe(gb.total)
    if isa(filter_assignments, Bool) && filter_assignments
        filter_assignments = nothing
        assignments = filter(assignments) do assignment
            values = safe_total[students_idx, assignment.codename]
            2 * count(x -> !ismissing(x), values) > length(students_idx)
        end
    end
    cols = map(a->a.codename, assignments)
    df_raw = safe_raw[students_idx, Cols(cols...)]
    df_penalty = safe_penalty[students_idx, Cols(cols...)]
    df_total = safe_total[students_idx, Cols(cols...)]

    df_total.Raw = get_rawpoints(df_raw, safe_raw[students_idx, :]; viewing_attendance=viewing_attendance)
    df_total.Penalty = get_penaltypoints(gb.penalty, df_penalty, [students_idx...]; filter_assignments=filter_assignments, viewing_attendance=viewing_attendance)
    df_total.Total = get_totalpoints(df_total; viewing_attendance=viewing_attendance)

    total_possible = get_totalpossible(assignments; viewing_attendance=viewing_attendance)
    df_total.Percent = get_percent(df_total, total_possible)

    df = DataFrame(
        Raw = df_total.Raw,
        Penalty = df_total.Penalty,
        Total = df_total.Total,
        Percent = df_total.Percent
    )

    for (i, assignment) ∈ enumerate(assignments)
        insertcols!(df, i, assignment.codename=>map(g->ismissing(g) ? missing : (viewing_attendance ? g.status : g.submission.score.earned), [isassigned(gb.total[!, assignment.codename], ii) ? gb.total[ii, assignment.codename] : missing for ii ∈ students_idx]))
    end

    if !viewing_attendance
        df.Letter = get_lettergrade(df)
        df.GPA = get_gpa(df)
        df.Missing = get_missing(df, total_possible)
    end

    df.Absent = get_absent(gb, [students_idx...])

    if !viewing_attendance
        df.Extension = get_extension([students_idx...], gb.class.roster)
        df.Accommodation = get_accommodation([students_idx...], gb.class.roster)
    end

    column_labels = if !viewing_attendance
        [
            names(df),
            vcat(map(x->repr(x.category)[begin+11:end][begin:end-11], assignments), fill("", 10)),
            vcat(map(x->x.is_group ? "Group" : "Individual", assignments), fill("", 10)),
            vcat(map(x->repr(typeof(x).types[2]), assignments), fill("", 10)),
        ]
    else
        [
            names(df), # vcat(map(x->x.codename, filter(isattendance, gb.class.lectures)), fill("", 9)),
            # vcat(map(x->repr(x.category)[20:end], filter(isattendance, gb.class.lectures)), fill("", 9)),
            # vcat(map(x->x.is_group ? "Group" : "Individual", filter(isattendance, gb.class.lectures)), fill("", 9)),
            # vcat(map(x->repr(typeof(x).types[2]), filter(isattendance, gb.class.lectures)), fill("", 9)),
        ]
    end

    data = [
        map(s->!isempty(s.person.name_preferred) ? s.person.name_preferred : s.person.name_given, gb.class.roster.students[students_idx]), # Preferred
        map(s->s.person.name_family, gb.class.roster.students[students_idx]), # Last
        map(s->s.person.id, gb.class.roster.students[students_idx]), # ID
        map(s->s.person.email, gb.class.roster.students[students_idx]), # Email
    ]
    if !isempty(gb.class.teams)
        team_names = String[]
        for student ∈ gb.class.roster.students[students_idx]
            found = false
            for team ∈ gb.class.teams
                if any(t -> t.person.id == student.person.id, team.roster.students)
                    push!(team_names, team.name)
                    found = true
                    break
                end
            end
            if !found
                push!(team_names, "")
            end
        end
    end

    return df, assignments, column_labels, [join(collect(row), " ") for row ∈ zip(data...)]
end


"View gradebook for entire class or subset according to index filter of assignments or students."
function view_gradebook(
    gb::Gradebook;
    filter_assignments=true,
    filter_students=isactive,
    display_credits=DISPLAY_CREDITS,
    output_path=joinpath(pwd(), "gradebook", "build", "gradebook.html")
)
    df, assignments, column_labels, row_labels = build_gradebook_display(gb;
        filter_assignments=filter_assignments,
        filter_students=filter_students,
        display_credits=display_credits
    )

    return render_table(
        df;
        title="$(gb.class.codename_long): $(gb.class.course.name)",
        subtitle="Class Gradebook",
        output_path=output_path,
        column_labels=column_labels,
        row_labels=row_labels,
        summary_row_labels=["Worth", "Due"], # , "Average (Point)", "Average (Percent)"],
        summary_rows=[
            (matrix, j)->j <= length(assignments) ? assignments[j].value : ( # all cells before summary columns
                j == length(assignments) + 1 ? mapreduce(a->a.value, +, assignments) : ( # raw
                    j == length(assignments) + 3 ? mapreduce(a->a.value, +, assignments) : ( # total
                        ""))),
            (matrix, j)->j <= length(assignments) ? assignments[j].due : (j == length(assignments) + 1 ? gb.class.term.finish : ""),
            # (matrix, j)->j <= length(assignments) + 3 ? Point(sum(df[:, j])/length(df[:, j])) : ( # all cells + raw, penalty, and total
            #     j <= length(assignments) + 5 ? credit2lettergrade(Percent(sum(df[:, j-2])/length(df[:, j-2]); normalize=false)) : ( # letter
            #         j <= length(assignments) + 6 ? mapreduce(ℓ->ℓ.quality_points, +, df[:, j-1])/length(df[:, j-1]) : ( # gpa
            #             j <= length(assignments) + 8 ? sum(df[:, j])/length(df[:, j]) : ( # missing and absent
            #                 "")))),
            # (matrix, j)->j <= length(assignments) ? Percent(float(sum(df[:, j]))/length(df[:, j]) / assignments[j].value.value; normalize=false) : 0.0
        ],
        invert_cols=Set(["Missing", "Penalty", "Absent"])
    )
end

"View detailed breakdown of assignment performance across entire class or subset according to index filter of students."
function view_assignment(
    gb::Gradebook,
    assignment::Assignment;
    filter_students=isactive,
    display_credits=DISPLAY_CREDITS,
    output_path=joinpath(pwd(), "gradebook", "build", "assignment.html")
)
    df, items, column_labels, row_labels = build_assignment_display(gb, gb.total[!, assignment.codename], assignment; filter_students=filter_students, teams=gb.class.teams, display_credits=display_credits)

    return render_table(
        df;
        title="$(assignment.name) ($(assignment.value) points)",
        subtitle="Assignment Breakdown",
        output_path=output_path,
        column_labels=column_labels,
        row_labels=row_labels,
        summary_row_labels=["Worth"], # , "Average (Point)", "Average (Percent)"],
        summary_rows=[
            (matrix, j)->j <= length(items) ? items[j].value : "",
            # (matrix, j)->j <= length(items) ? Point(sum(df[:, j])/length(df[:, j])) : 0.0,
            # (matrix, j)->j <= length(items) ? Percent(float(sum(df[:, j]))/length(df[:, j]) / items[j].value.value; normalize=false) : 0.0
        ],
        invert_cols=Set(["Missing"])
    )
end

function fit_assignment_trend(assignments, scores, cutoff, is_group)
    history = findall(j ->
        assignments[j].due <= cutoff &&
        assignments[j].is_group == is_group,
        eachindex(assignments))

    isempty(history) && return nothing

    # Missing assignments due by the cutoff count as zero.
    y = [isnan(scores[j]) ? 0.0 : scores[j] for j in history]
    x = Float64.(history)
    n = length(history)
    mean_x = sum(x) / n
    mean_y = sum(y) / n
    sxx = sum((xj - mean_x)^2 for xj in x)

    slope = n > 1 && sxx > 0 ?
        sum((x[k] - mean_x) * (y[k] - mean_y) for k in eachindex(x)) / sxx : 0.0
    intercept = mean_y - slope * mean_x

    residual_variance = if n >= 3 && sxx > 0
        residual_ss = sum(
            (y[k] - (intercept + slope * x[k]))^2
            for k in eachindex(x)
        )
        residual_ss / (n - 2)
    else
        NaN
    end

    return (; n, mean_x, sxx, slope, intercept, residual_variance)
end

function forecast_final_grade(assignments, scores, cutoff, confidence)
    history = findall(j -> assignments[j].due <= cutoff, eachindex(assignments))
    isempty(history) && return nothing

    future = findall(j ->
        assignments[j].due > cutoff && isnan(scores[j]),
        eachindex(assignments))

    individual_model = fit_assignment_trend(assignments, scores, cutoff, false)
    group_model = fit_assignment_trend(assignments, scores, cutoff, true)

    n_assignments = length(assignments)
    predicted = fill(NaN, n_assignments)
    lower_predictions = fill(NaN, n_assignments)
    upper_predictions = fill(NaN, n_assignments)

    for j in future
        model = assignments[j].is_group ? group_model : individual_model
        isnothing(model) && continue

        predicted[j] = clamp(
            model.intercept + model.slope * j, 0.0, 1.0
        )

        if !isnothing(confidence) && isfinite(model.residual_variance)
            critical_value = quantile(
                TDist(model.n - 2),
                (1 + confidence) / 2
            )
            prediction_sd = sqrt(
                model.residual_variance *
                (1 + 1 / model.n + (j - model.mean_x)^2 / model.sxx)
            )
            margin = critical_value * prediction_sd
            lower_predictions[j] = clamp(predicted[j] - margin, 0.0, 1.0)
            upper_predictions[j] = clamp(predicted[j] + margin, 0.0, 1.0)
        end
    end

    points = [a.value.value for a in assignments]
    total_possible = sum(points)
    known_earned = sum(
        isnan(scores[j]) ? 0.0 : scores[j] * points[j]
        for j in eachindex(assignments)
    )

    forecast_available = all(j -> !isnan(predicted[j]), future)
    final_grade = if forecast_available && total_possible > 0
        forecast_earned = sum(predicted[j] * points[j] for j in future)
        100 * (known_earned + forecast_earned) / total_possible
    else
        nothing
    end

    lower_grade = nothing
    upper_grade = nothing

    if !isnothing(confidence) && !isnothing(final_grade)
        if isempty(future)
            lower_grade = final_grade
            upper_grade = final_grade
        else
            variance_components = Tuple{Float64, Int}[]
            intervals_available = true

            for (is_group, model) in ((false, individual_model), (true, group_model))
                type_future = filter(j ->
                    assignments[j].is_group == is_group,
                    future)
                isempty(type_future) && continue

                if isnothing(model) || !isfinite(model.residual_variance)
                    intervals_available = false
                    break
                end

                type_points = points[type_future]
                total_type_points = sum(type_points)
                weighted_x_deviation = sum(
                    type_points[k] * (type_future[k] - model.mean_x)
                    for k in eachindex(type_future)
                )

                variance = model.residual_variance * (
                    sum(p^2 for p in type_points) +
                    total_type_points^2 / model.n +
                    weighted_x_deviation^2 / model.sxx
                )
                push!(variance_components, (variance, model.n - 2))
            end

            if intervals_available && !isempty(variance_components)
                total_variance = sum(first, variance_components)
                denominator = sum(
                    variance^2 / degrees_freedom
                    for (variance, degrees_freedom) in variance_components
                )
                degrees_freedom = denominator > 0 ?
                    total_variance^2 / denominator :
                    minimum(last, variance_components)
                margin_points = quantile(
                    TDist(degrees_freedom),
                    (1 + confidence) / 2
                ) * sqrt(total_variance)

                future_points = sum(points[future])
                known_points = known_earned
                forecast_earned = sum(predicted[j] * points[j] for j in future)

                lower_grade = 100 * clamp(
                    known_points + forecast_earned - margin_points,
                    known_points,
                    known_points + future_points
                ) / total_possible
                upper_grade = 100 * clamp(
                    known_points + forecast_earned + margin_points,
                    known_points,
                    known_points + future_points
                ) / total_possible
            end
        end
    end

    return (;
        history,
        future,
        predicted,
        lower_predictions,
        upper_predictions,
        final_grade,
        lower_grade,
        upper_grade,
        individual_model,
        group_model
    )
end

function forecast_running_series(assignments, scores, cutoff, result, confidence)
    n = length(assignments)
    running = fill(NaN, n)
    lower = fill(NaN, n)
    upper = fill(NaN, n)
    points = [a.value.value for a in assignments]

    cutoff_index = last(result.history)
    fixed_earned = 0.0
    fixed_possible = 0.0
    forecast_earned = 0.0
    forecast_possible = 0.0
    projected_indices = Int[]

    for j in 1:n
        if j in result.history
            score = isnan(scores[j]) ? 0.0 : scores[j]
            fixed_earned += score * points[j]
            fixed_possible += points[j]
        elseif !isnan(scores[j])
            fixed_earned += scores[j] * points[j]
            fixed_possible += points[j]
        elseif !isnan(result.predicted[j])
            forecast_earned += result.predicted[j] * points[j]
            forecast_possible += points[j]
            push!(projected_indices, j)
        else
            # A future assignment without a matching category model makes
            # later cumulative predictions incomplete.
            break
        end

        cumulative_possible = fixed_possible + forecast_possible
        if j == cutoff_index || j > cutoff_index
            running[j] = 100 * (fixed_earned + forecast_earned) / cumulative_possible
        end

        if isnothing(confidence) || j <= cutoff_index || isempty(projected_indices)
            continue
        end

        variance_components = Tuple{Float64, Int}[]
        intervals_available = true

        for (is_group, model) in (
            (false, result.individual_model),
            (true, result.group_model),
        )
            type_indices = filter(
                k -> assignments[k].is_group == is_group,
                projected_indices
            )
            isempty(type_indices) && continue

            if isnothing(model) || !isfinite(model.residual_variance)
                intervals_available = false
                break
            end

            type_points = points[type_indices]
            total_type_points = sum(type_points)
            weighted_x_deviation = sum(
                type_points[k] * (type_indices[k] - model.mean_x)
                for k in eachindex(type_indices)
            )

            variance = model.residual_variance * (
                sum(p^2 for p in type_points) +
                total_type_points^2 / model.n +
                weighted_x_deviation^2 / model.sxx
            )
            push!(variance_components, (variance, model.n - 2))
        end

        if !intervals_available || isempty(variance_components)
            continue
        end

        total_variance = sum(first, variance_components)
        denominator = sum(
            variance^2 / degrees_freedom
            for (variance, degrees_freedom) in variance_components
        )
        degrees_freedom = denominator > 0 ?
            total_variance^2 / denominator :
            minimum(last, variance_components)
        margin = quantile(TDist(degrees_freedom), (1 + confidence) / 2) *
            sqrt(total_variance)

        min_earned = fixed_earned
        max_earned = fixed_earned + forecast_possible
        expected_earned = fixed_earned + forecast_earned

        lower[j] = 100 * clamp(
            expected_earned - margin, min_earned, max_earned
        ) / cumulative_possible
        upper[j] = 100 * clamp(
            expected_earned + margin, min_earned, max_earned
        ) / cumulative_possible
    end

    return (; running, lower, upper)
end

function view_assignment_trends(
    gb::Gradebook;
    filter_students=nothing,
    filter_teams=nothing,
    forecast=false,
    forecast_confidence=nothing,
    forecast_bandfill=false,
    output_path=joinpath(pwd(), "gradebook", "build", "assignment_trends.png")
)
    all_assignments = sort(copy(gb.class.course.assignments); by=a -> a.due)
    isempty(all_assignments) &&
        throw(ArgumentError("The course has no assignments"))
    # any(a -> a.value.value <= 0, all_assignments) &&
    #     throw(ArgumentError("Assignment trend plots require positive assignment values"))

    student_indices = isnothing(filter_students) ? Int[] :
        collect(get_students(gb; filter_students=filter_students))

    teams = if isnothing(filter_teams)
        Team[]
    elseif filter_teams isa Team
        Team[filter_teams]
    elseif filter_teams isa AbstractString
        Team[get_team(String(filter_teams), gb.class.teams)]
    elseif filter_teams isa AbstractVector{<:Team}
        collect(filter_teams)
    elseif filter_teams isa AbstractVector{<:AbstractString}
        map(name -> get_team(String(name), gb.class.teams), filter_teams)
    else
        throw(ArgumentError(
            "filter_teams must be a Team, team name, or vector of Teams or team names"
        ))
    end

    team_indices = Int[]
    for team in teams
        append!(team_indices, get_students(gb; filter_students=team.roster))
    end

    cohort_indices = if isnothing(filter_students) && isnothing(filter_teams)
        findall(isactive, gb.class.roster.students)
    else
        unique(vcat(student_indices, team_indices))
    end

    isempty(cohort_indices) &&
        throw(ArgumentError("The selected student and team filters contain no students"))
    forecast && isempty(student_indices) &&
        throw(ArgumentError("forecast=true requires filter_students to select at least one student"))
    if !isnothing(forecast_confidence) &&
       (!(forecast_confidence isa Real) ||
        !isfinite(forecast_confidence) ||
        !(0 < forecast_confidence < 1))
        throw(ArgumentError("forecast_confidence must be between 0 and 1, or nothing"))
    end

    n_students = length(gb.class.roster.students)
    n_assignments = length(all_assignments)
    # now_dt = now()
    now_dt = begin
        assignments = filter(all_assignments) do assignment
            grades = gb.total[!, assignment.codename]
            2 * count(i -> isassigned(grades, i), cohort_indices) > length(cohort_indices)
        end
        isempty(assignments) ? now() : maximum(map(a->a.due, assignments))
    end

    scores = fill(NaN, n_students, n_assignments)
    for (j, assignment) in enumerate(all_assignments)
        grades = gb.total[!, assignment.codename]
        for i in 1:n_students
            if isassigned(grades, i)
                scores[i, j] =
                    grades[i].submission.score.earned.value / assignment.value.value
            end
        end
    end

    bar_indices = findall(all_assignments) do assignment
        grades = gb.total[!, assignment.codename]
        2 * count(i -> isassigned(grades, i), cohort_indices) > length(cohort_indices)
    end
    isempty(bar_indices) &&
        throw(ArgumentError("No assignments are graded for more than half of the selected cohort"))

    class_assignment = fill(NaN, n_assignments)
    class_running = fill(NaN, n_assignments)
    class_earned = 0.0
    class_possible = 0.0

    for j in 1:n_assignments
        assignment = all_assignments[j]
        is_due = assignment.due <= now_dt
        values = Float64[]

        for i in cohort_indices
            score = scores[i, j]
            if !isnan(score)
                push!(values, score)
                class_earned += score * assignment.value.value
                class_possible += assignment.value.value
            elseif is_due
                push!(values, 0.0)
                class_possible += assignment.value.value
            end
        end

        if !isempty(values)
            class_assignment[j] = sum(values) / length(values)
        end
        if class_possible > 0
            class_running[j] = class_earned / class_possible
        end
    end

    x_all = collect(eachindex(all_assignments))
    labels = map(a -> a.codename, all_assignments)
    if !forecast
        x_all = filter(j -> !isnan(class_assignment[j]), x_all)
        labels = labels[x_all]
    end
    legend_entries = NamedTuple[]
    p = bar(
        [bar_indices .- 0.15, bar_indices .+ 0.15],
        100 .* hcat(class_assignment[bar_indices], class_running[bar_indices]);
        bar_position=:dodge,
        bar_width=0.2,
        seriescolor=[:blue :orange],
        # fill_z=[class_assignment[bar_indices] class_running[bar_indices]],
        label=["Class assignment average" "Class running average"],
        xticks=(x_all, labels),
        xrotation=45,
        yticks=0:10:100,
        ylabel="Performance (%)",
        title="$(gb.class.codename): Assignment Trends",
        legend=:none,
        framestyle=:box,
    )
    hline!([90], color=:black, linestyle=:solid, label="")
    Plots.annotate!([(last(x_all), 92, text("A", :black, :right, 10, rotation=0))])
    hline!([80], color=:black, linestyle=:solid, label="")
    Plots.annotate!([(last(x_all), 82, text("B", :black, :right, 10, rotation=0))])
    hline!([70], color=:black, linestyle=:solid, label="")
    Plots.annotate!([(last(x_all), 72, text("C", :black, :right, 10, rotation=0))])
    hline!([60], color=:black, linestyle=:solid, label="")
    Plots.annotate!([(last(x_all), 62, text("D", :black, :right, 10, rotation=0))])
    hline!([50], color=:black, linestyle=:solid, label="")
    Plots.annotate!([(last(x_all), 52, text("F", :black, :right, 10, rotation=0))])
    vline!([findlast(j -> all_assignments[j].due <= now_dt, eachindex(all_assignments))+0.5], color=:black, linestyle=:solid, label="")
    Plots.annotate!([(findlast(j -> all_assignments[j].due <= now_dt, eachindex(all_assignments))+0.25, 90, text("Graded so far", :black, :center, 10, rotation=90))])

    # Each time you add a series to p, also register a matching entry:
    push!(legend_entries, (
        label = "Class assignment average",
        color = :blue,
        kind = :bar,
    ))
    push!(legend_entries, (
        label = "Class running average: $(round(100class_running[end]; digits=2))% ($(credit2lettergrade(Percent(class_running[end]; normalize=false))))",
        color = :orange,
        kind = :bar,
    ))

    n_selected = length(student_indices)
    student_colors = [
        get(colorschemes[:viridis],
            0.1 + 0.8 * (i - 1) / max(n_selected - 1, 1))
        for i in 1:n_selected
    ]

    for (student_number, student_index) in enumerate(student_indices)
        student_color = student_colors[student_number]
        selected_student = gb.class.roster.students[student_index]
        student_name = isempty(selected_student.person.name_preferred) ?
            selected_student.person.name_given : selected_student.person.name_preferred
        student_scores = scores[student_index, :]
        student_running = fill(NaN, n_assignments)
        earned = 0.0
        possible = 0.0

        for j in 1:n_assignments
            assignment = all_assignments[j]
            score = student_scores[j]

            if !isnan(score)
                earned += score * assignment.value.value
                possible += assignment.value.value
            elseif assignment.due <= now_dt
                student_scores[j] = 0.0
                possible += assignment.value.value
            end

            if possible > 0
                student_running[j] = 100 * earned / possible
            end
        end

        x = findall(j -> !isnan(student_scores[j]), eachindex(all_assignments))

        # Each time you add a series to p, also register a matching entry:
        entry = (
            label = "$student_name performance: $(round(possible - earned; digits=2)) points missing",
            color = student_color,
            kind = :scatter,
            linestyle = :solid,
            marker = :circle,
        )
        push!(legend_entries, entry)

        scatter!(p, x, 100 .* student_scores[1:length(x)];
            label=false,
            color=entry.color,
            marker=entry.marker,
            # linestyle=entry.linestyle,
            linewidth=2)
        plot!(p, x, 100 .* student_scores[1:length(x)];
            label=false,
            color=entry.color,
            marker=:none,
            linestyle=entry.linestyle,
            linewidth=2)

        # Each time you add a series to p, also register a matching entry:
        entry = (
            label = "$student_name running average: $(round(student_running[length(x)]; digits=2))% ($(credit2lettergrade(Percent(student_running[length(x)] / 100; normalize=false))))",
            color = student_color,
            kind = :scatter,
            linestyle = :dash,
            marker = :diamond,
        )
        push!(legend_entries, entry)

        scatter!(p, x, student_running[1:length(x)];
            label=false,
            color=entry.color,
            marker=entry.marker,
            # linestyle=entry.linestyle,
            linewidth=2)
        plot!(p, x, student_running[1:length(x)];
            label=false,
            color=entry.color,
            marker=:none,
            linestyle=entry.linestyle,
            linewidth=2)

        if forecast
            result = forecast_final_grade(
                all_assignments, student_scores, now_dt, forecast_confidence
            )

            if !isempty(result.future)
                running_forecast = forecast_running_series(
                    all_assignments, student_scores, now_dt, result, forecast_confidence
                )

                anchor = last(result.history)
                anchor_value = student_running[anchor]
                
                if !isnan(anchor_value)
                    running_forecast.running[anchor] = anchor_value
                
                    if !isempty(filter(j -> !isnan(running_forecast.lower[j]), result.future))
                        running_forecast.lower[anchor] = anchor_value
                    end
                    if !isempty(filter(j -> !isnan(running_forecast.upper[j]), result.future))
                        running_forecast.upper[anchor] = anchor_value
                    end
                end

                if !isnothing(forecast_confidence) && !isnothing(result.upper_grade)
                    band_indices = findall(j ->
                        !isnan(running_forecast.running[j]) &&
                        !isnan(running_forecast.lower[j]) &&
                        !isnan(running_forecast.upper[j]),
                        eachindex(all_assignments)
                    )
                    if forecast_bandfill && !isempty(band_indices)
                        forecast_values = running_forecast.running[band_indices]
                        plot!(p, band_indices, running_forecast.upper[band_indices];
                            fillrange=forecast_values,
                            fillcolor=student_color,
                            fillalpha=0.12,
                            linealpha=0,
                            label=false)
                    end
                    level = round(Int, 100 * forecast_confidence)
                    upper_indices = findall(j -> !isnan(running_forecast.upper[j]), eachindex(all_assignments))
                    if !isempty(upper_indices)
                        forecast_label = isnothing(result.final_grade) ?
                            "$student_name forecast" :
                            "$student_name forecast: $(round(result.final_grade; digits=2))%"

                        # Each time you add a series to p, also register a matching entry:
                        entry = (
                            label = "$student_name upper prediction: $(round(result.upper_grade; digits=2))% ($(credit2lettergrade(Percent(result.upper_grade / 100; normalize=false))))",
                            color = student_color,
                            kind = :line,
                            linestyle = :solid,
                            marker = :none,
                        )
                        push!(legend_entries, entry)
                        # plot!(p, result.future,
                        #     100 .* result.upper_predictions[result.future];
                        #     label=false,
                        #     color=entry.color,
                        #     linestyle=entry.linestyle,
                        #     linewidth=1.5)
                        # Add this entry and plot as the forecast series using the student's color.
                        plot!(p, upper_indices, running_forecast.upper[upper_indices];
                            label=false,
                            color=entry.color,
                            linestyle=entry.linestyle,
                            linewidth=2)
                    end
                end

                forecast_indices = findall(j -> !isnan(running_forecast.running[j]), eachindex(all_assignments))
                if !isempty(forecast_indices)
                    forecast_label = isnothing(result.final_grade) ?
                        "$student_name forecast" :
                        "$student_name forecast: $(round(result.final_grade; digits=2))%"

                    # Each time you add a series to p, also register a matching entry:
                    entry = (
                        label = "$student_name forecast: $(round(result.final_grade; digits=2))% ($(credit2lettergrade(Percent(result.final_grade / 100; normalize=false))))",
                        color = student_color,
                        kind = :line,
                        linestyle = :dash,
                        marker = :none,
                    )
                    push!(legend_entries, entry)
                    # plot!(p, result.future, 100 .* result.predicted[result.future];
                    #     label=false,
                    #     color=entry.color,
                    #     linestyle=entry.linestyle,
                    #     linewidth=2)
                    # Add this entry and plot as the forecast series using the student's color.
                    plot!(p, forecast_indices, running_forecast.running[forecast_indices];
                        label=false,
                        color=entry.color,
                        linestyle=entry.linestyle,
                        linewidth=2)
                end

                if !isnothing(forecast_confidence) && !isnothing(result.lower_grade)
                    band_indices = findall(j ->
                        !isnan(running_forecast.running[j]) &&
                        !isnan(running_forecast.lower[j]) &&
                        !isnan(running_forecast.upper[j]),
                        eachindex(all_assignments)
                    )
                    if forecast_bandfill && !isempty(band_indices)
                        forecast_values = running_forecast.running[band_indices]
                        plot!(p, band_indices, running_forecast.lower[band_indices];
                            fillrange=forecast_values,
                            fillcolor=student_color,
                            fillalpha=0.12,
                            linealpha=0,
                            label=false)
                    end
                    level = round(Int, 100 * forecast_confidence)
                    lower_indices = findall(j -> !isnan(running_forecast.lower[j]), eachindex(all_assignments))
                    if !isempty(lower_indices)
                        forecast_label = isnothing(result.final_grade) ?
                            "$student_name forecast" :
                            "$student_name forecast: $(round(result.final_grade; digits=2))%"

                        # Each time you add a series to p, also register a matching entry:
                        entry = (
                            label = "$student_name lower prediction: $(round(result.lower_grade; digits=2))% ($(credit2lettergrade(Percent(result.lower_grade / 100; normalize=false))))",
                            color = student_color,
                            kind = :line,
                            marker = :none,
                            linestyle = :dot,
                        )
                        push!(legend_entries, entry)
                        # plot!(p, result.future,
                        #     100 .* result.lower_predictions[result.future];
                        #     label=false,
                        #     color=entry.color,
                        #     linestyle=entry.linestyle,
                        #     linewidth=1.5,
                        #     legendtitle="$level% confidence interval")
                        # Add this entry and plot as the forecast series using the student's color.
                        plot!(p, lower_indices, running_forecast.lower[lower_indices];
                            label=false,
                            color=entry.color,
                            linestyle=entry.linestyle,
                            linewidth=2)
                        plot!(p, legendtitle="$level% confidence interval")
                    end
                end
            end
        end
    end

    legend_plot = plot(;
        legend=:left,
        legendtitle=isnothing(forecast_confidence) ?
            "Assignment trends" :
            "$(round(Int, 100 * forecast_confidence))% prediction interval",
        framestyle=:none,
        grid=false,
        axis=false,
    )

    for entry in legend_entries
        if entry.kind == :bar
            bar!(legend_plot, [NaN], [NaN];
                label=entry.label,
                color=entry.color)
        elseif entry.kind == :scatter
            scatter!(legend_plot, [NaN], [NaN];
                label=entry.label,
                color=entry.color,
                marker=entry.marker)
        else
            plot!(legend_plot, [NaN], [NaN];
                label=entry.label,
                color=entry.color,
                marker=entry.marker,
                # markersize=32,
                # markerstrokewidth=0.1,
                linestyle=entry.linestyle)
        end
    end

    combined = plot(
        p,
        legend_plot;
        layout=@layout([graph{0.75w} legend{0.25w}]),
        size=(1200, 800),
        margin=5Plots.mm,
        dpi=300
    )

    mkpath(dirname(output_path))
    savefig(combined, output_path)
    return combined
end

"Similar to `view_gradebook` but specialized for attendance."
function view_attendance(
    gb::Gradebook;
    filter_assignments=true,
    filter_students=isactive,
    output_path=joinpath(pwd(), "gradebook", "build", "attendance.html")
)
    df, records, column_labels, row_labels = build_gradebook_display(
        gb;
        filter_assignments=filter_assignments,
        viewing_attendance=true,
        filter_students=filter_students
    )

    return render_table(
        df;
        title="$(gb.class.course.name)",
        subtitle="Attendance",
        output_path=output_path,
        column_labels=column_labels,
        row_labels=row_labels,
        summary_row_labels=["Due", "Present", "Present (Average)"],
        summary_rows=[
            (matrix, j)->j <= length(records) ? Date(records[j].due) : "",
            (matrix, j)->j <= length(records) ? count(ispresent, df[:, j]) : "",
            (matrix, j)->j <= length(records) ? count(ispresent, df[:, j])/length(df[:, j]) : ""
        ],
        invert_cols=Set(["Missing", "Absent"])
    )
end

function view_major_distribution(gb::Gradebook; output_path=joinpath(pwd(), "gradebook", "build", "major_distribution.png"))
    disciplines = sort(unique(map(x->x.discipline, gb.class.roster.students)))
    data = Tuple{Integer, String, Integer}[]
    for (i, d) in enumerate(disciplines)
        push!(data, (i, d, count(x->x.discipline==d, gb.class.roster.students)))
    end
    x, y = map(first, data), map(last, data)
    z = map(x->x[2], data)
    # p = bar(x, y;
    #         label="",
    #         xgrid=false,
    #         xticks=(x, map(x->x[2], data)),
    #         xrotation=45,
    #         ylims=(0, iseven(maximum(y)) ? maximum(y) : (maximum(y) + 1)),
    #         yticks=(0:2:(iseven(maximum(y)) ? maximum(y) : (maximum(y) + 1)), 0:2:(iseven(maximum(y)) ? maximum(y) : (maximum(y) + 1))),
    #         title="Distribution of Major (N=$(mapreduce(last, +, data)))",
    #         framestyle=:box,
    #         dpi=300,
    #     )
    p = pie(["$(z[i]) ($(y[i]))" for i in 1:length(x)], y;
            title="Distribution of Major (N=$(mapreduce(last, +, data)))",
            framestyle=:box,
            dpi=300,
        )
    # display(p)
    savefig(p, output_path)
end

function view_attendance_tree_ring(gb::Gradebook; output_path=joinpath(pwd(), "gradebook", "build", "attendance_tree_ring.png"))
    # https://discourse.julialang.org/t/radar-plot-in-plots-jl-or-makie-jl/88576/4
    attendance_average = Tuple{Student, Percent}[]
    for (i, row) ∈ enumerate(eachrow(gb.raw))
        push!(attendance_average, (gb.class.roster.students[i], Percent((length(gb.class.lectures) - count(isabsent, row[findall(j->isassigned(gb.raw[!, j], i), 1:ncol(gb.raw))])) / length(gb.class.lectures); normalize=false)))
    end
    n = length(gb.class.roster)
    Δθ = 2π/n
    θ = collect(range(Δθ/2, 2π-Δθ/2; length=n))
    push!(θ, first(θ))
    r = map(y->100(y[2].value), attendance_average)
    push!(r, first(r))
    y_min = floor(minimum(r)) - (floor(minimum(r)) % 10)
    Δr = y_min >= 90 ? 1 : (y_min >= 80 ? 2 : (y_min >= 50 ? 5 : 10))
    p = plot(θ, r; label="Attendance", legend_position=(0.825, -0.025),
        proj=:polar,
        xaxis=false,
        # xticks=(0:15:360, map(x->"$x", 0:15:360)),
        ylims=(y_min, 100),
        yticks=(0:Δr:100, map(x->"$x %", 0:Δr:100)),
        ytickfontsize=8,
        ytickfontfamily="Computer Modern",
        markercolor=:blue,
        markershape=:circle,
        markersize=3,
        fillrange=y_min,
        fillalpha=0.15,
        gridalpha=0.4,
        # title="Attendance",
        # titlefontfamily="Computer Modern",
        # margin=5Plots.mm,
        left_margin=-10Plots.mm,
        aspect_ratio=:none,
        size=(400, 400),
        dpi=300,
    )
    z = 1.10*exp.(im*2π*(0.5:n-0.5)/n)
    Plots.annotate!(p, real.(z), imag.(z), text.(map(x->x[1].final_grade, attendance_average), 8, "Computer Modern"))
    # display(p)
    savefig(p, output_path)
end
