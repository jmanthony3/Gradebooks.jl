export view_gradebook, view_assignment, view_attendance



using DataFrames
using PrettyTables
using Colors
using ColorSchemes



numeric_value(x::Real) = Float64(x)
numeric_value(x::Credit) = x.value
numeric_value(x::Grade) = Float64(x.submission.score.earned)
numeric_value(x) = NaN

function column_bounds(df::DataFrame, j::Int)
    vals = filter(!isnan, map(numeric_value, df[:, j]))
    return isempty(vals) ? (0.0, 1.0) : (minimum(vals), maximum(vals))
end

# function color_for_value(_, v, lo, hi; invert=false)
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
        # if invert
        #     s = 1 - s
        # end
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
    for j in 1:ncol(df)
        push!(hls, HtmlHighlighter(
            (data, i, jj) -> jj == j,
            # map(i->"background-color" => color_for_value(df[i, j], column_bounds(df, j)...; invert=(df_names[j] ∈ invert_cols)), 1:nrow(df))
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

    return nothing
end

function resolve_display_value(earned::Point, item, parent_value; display_credits=DISPLAY_CREDITS)
    leaf_value = resolve_leaf_point_value(item, parent_value)

    if display_credits == "point"
        return earned
    elseif display_credits == "percent"
        return Percent(earned.value / leaf_value.value; normalized=false)
    elseif display_credits == "auto"
        if isa(item.value, Percent)
            return Percent(earned.value / leaf_value.value; normalized=false)
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
            # leaf_value = resolve_leaf_point_value(item, parent_value)
            # Point(leaf_value.value * δ.value)
            Point(current_value.value * δ.value)
        else
            Point(0.0)
        end
    end
    return resolve_display_value(earned, item, parent_value; display_credits=display_credits)
end

function total_for_grade(g, flat_leaves, assignment; display_credits=DISPLAY_CREDITS)
    points = 0.0
    for (path, leaf, parent_value, current_value) in flat_leaves
        score = leaf_score(path, leaf, g.submission.evaluations, parent_value, current_value; display_credits="point")
        points += score.value
    end

    return if display_credits == "percent"
        Percent(points / assignment.value.value; normalized=false)
    else
        Point(points)
    end
end

function build_assignment_display(gb::Gradebook, grades::Vector{Grade}, assignment::Assignment; student_filter=nothing, teams=Team[], display_credits=DISPLAY_CREDITS)
    students_idx = !isnothing(student_filter) ? student_filter : (1:nrow(gb.total))
    grades = grades[students_idx]
    # collect all leaf nodes once, with a unique display codename
    # flat_leaves = vcat((leaf_items(q; prefix=assignment.codename, parent_value=assignment.value) for q in assignment.questions)...)
    flat_leaves = flatten_leaves(assignment; parent_value=assignment.value)
    all_leaves = [leaf for (_, leaf, _, _) in flat_leaves]

    # total_values = map(g -> total_for_grade(g, flat_leaves, assignment; display_credits=display_credits), grades)
    total_values = map(g->display_credits == "percent" ? g.submission.score.percent : g.submission.score.earned, grades)

    df = DataFrame(
        Total = total_values,
        Percent = map(total_values) do t
            if t isa Percent
                t
            else
                Percent(t.value / assignment.value.value; normalized=false)
            end
        end,
        Letter = map(total_values) do t
            if t isa Percent
                credit2lettergrade(t)
            else
                credit2lettergrade(t, assignment.value)
            end
        end,
        Missing = map(total_values) do t
            if t isa Percent
                Point(assignment.value.value * (1 - t.value))
            else
                Point(assignment.value.value - t.value)
            end
        end
    )

    # add one column per leaf using the prefixed display codename
    for (i, (path, leaf, parent_value, current_value)) in enumerate(flat_leaves)
        codename = Symbol(join(path.parts, "."))
        insertcols!(df, i, codename => map(g -> leaf_score(path, leaf, g.submission.evaluations, parent_value, current_value; display_credits=display_credits), grades))
    end

    # # summary columns
    # df.Total = map(g -> g.submission.score.earned, grades)
    # df.Percent = map(g -> g.submission.score.percent, grades)
    # df.Letter = map(g -> g.submission.score.letter.string, grades)
    # df.Missing = map(g -> assignment.value - g.submission.score.earned, grades)

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
        for student in gb.class.roster.students[students_idx]
            found = false
            for team in gb.class.teams
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

    return df, all_leaves, column_labels, [join(collect(row), " ") for row in zip(data...)]
end

function build_gradebook_display(gb::Gradebook;
    assignment_filter=nothing,
    includes_bonus=false,
    viewing_attendance=false,
    student_filter=nothing,
    display_credits=DISPLAY_CREDITS
)
    assignments = if viewing_attendance
        !isnothing(assignment_filter) ? gb.class.lectures[assignment_filter] : gb.class.lectures
    else
        !isnothing(assignment_filter) ? gb.class.course.assignments[assignment_filter] : gb.class.course.assignments[findall(!isattendance, gb.class.course.assignments)]
    end
    students_idx = !isnothing(student_filter) ? student_filter : (1:nrow(gb.total))

    cols = map(a->a.codename, assignments)
    df_raw = gb.raw[students_idx, Cols(cols...)]
    df_penalty = gb.penalty[students_idx, Cols(cols...)]
    df_total = gb.total[students_idx, Cols(cols...)]

    df_total.Raw = if viewing_attendance
        # map(eachrow(df_raw)) do row
        map(map(i->df_raw[i, filter(j->isassigned(Matrix(df_raw), i, j), 1:ncol(df_raw))], students_idx)) do row
            count(ispresent, row)
        end
    else
        map(eachrow(df_raw)) do row
            sum(row[c].submission.score.earned for c in cols)
        end
    end

    df_total.Penalty = map(eachrow(df_penalty)) do row
        sum(row[c] for c in cols)
    end

    df_total.Total = if viewing_attendance
        df_total.Penalty
    else
        df_total.Raw - df_total.Penalty
    end

    total_possible = viewing_attendance ? length(assignments) : mapreduce(a->a.value.value, +, collect(assignments)[begin:end-(includes_bonus ? 1 : 0)]; init=0.0)
    df_total.Percent = map(df_total.Total) do t
        Percent(t.value / total_possible; normalized=false)
    end

    df = DataFrame(
        # Preferred = map(s -> !isempty(s.person.name_preferred) ? s.person.name_preferred : s.person.name_given, gb.class.roster.students[students_idx]),
        # Last = map(s -> s.person.name_family, gb.class.roster.students[students_idx]),
        # ID = map(s -> s.person.id, gb.class.roster.students[students_idx]),
        # Email = map(s -> s.person.email, gb.class.roster.students[students_idx]),
        # summary columns
        Raw = df_total.Raw,
        Penalty = df_total.Penalty,
        Total = df_total.Total,
        Percent = df_total.Percent
    )

    for (i, assignment) in enumerate(assignments)
        insertcols!(df, i, assignment.codename=>map(g->ismissing(g) ? missing : (viewing_attendance ? g.status : g.submission.score.earned), [isassigned(gb.total[!, assignment.codename], ii) ? gb.total[ii, assignment.codename] : missing for ii in students_idx]))
    end

    if !viewing_attendance
        df.Letter = map(df.Percent) do p
            credit2lettergrade(p)
        end

        df.Missing = map(df.Total) do t
            Point(total_possible - t.value)
        end
    end

    df.Absent = map(map(i->gb.raw[i, filter(j->isassigned(Matrix(gb.raw), i, j), 1:ncol(gb.raw))], students_idx)) do row
        count(isabsent, row)
    end

    if !viewing_attendance
        df.Extension = map(gb.class.roster.students[students_idx]) do student
            get(student.notes, "Extension", "")
        end

        df.Accommodation = map(gb.class.roster.students[students_idx]) do student
            get(student.notes, "Accommodation", "")
        end
    end

    column_labels = if !viewing_attendance
        [
            names(df), # vcat(map(x->x.codename, filter(!isattendance, gb.class.course.assignments)), fill("", 9)),
            vcat(map(x->repr(x.category)[20:end], assignments), fill("", 9)),
            vcat(map(x->x.is_group ? "Group" : "Individual", assignments), fill("", 9)),
            vcat(map(x->repr(typeof(x).types[2]), assignments), fill("", 9)),
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
        for student in gb.class.roster.students[students_idx]
            found = false
            for team in gb.class.teams
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

    return df, assignments, column_labels, [join(collect(row), " ") for row in zip(data...)]
end


"View gradebook for entire class or subset according to index filter of assignments or students."
function view_gradebook(
    gb::Gradebook;
    assignment_filter=nothing,
    includes_bonus=false,
    student_filter=nothing,
    display_credits=DISPLAY_CREDITS,
    output_path=joinpath(pwd(), "gradebook", "build", "gradebook.html")
)
    df, assignments, column_labels, row_labels = build_gradebook_display(gb;
        assignment_filter=assignment_filter,
        includes_bonus=includes_bonus,
        student_filter=student_filter,
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
            (matrix, j)->j <= length(assignments) ? assignments[j].value : "",
            (matrix, j)->j <= length(assignments) ? assignments[j].due : "",
            # (matrix, j)->j <= length(assignments) ? Point(sum(df[:, j])/length(df[:, j])) : 0.0,
            # (matrix, j)->j <= length(assignments) ? Percent(float(sum(df[:, j]))/length(df[:, j]) / assignments[j].value.value; normalized=false) : 0.0
        ],
        invert_cols=Set(["Missing", "Penalty", "Absent"])
    )
end

"View detailed breakdown of assignment performance across entire class or subset according to index filter of students."
function view_assignment(
    gb::Gradebook,
    assignment::Assignment;
    student_filter=nothing,
    display_credits=DISPLAY_CREDITS,
    output_path=joinpath(pwd(), "gradebook", "build", "assignment.html")
)
    df, items, column_labels, row_labels = build_assignment_display(gb, gb.total[!, assignment.codename], assignment; student_filter=student_filter, teams=gb.class.teams, display_credits=display_credits)

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
            # (matrix, j)->j <= length(items) ? Percent(float(sum(df[:, j]))/length(df[:, j]) / items[j].value.value; normalized=false) : 0.0
        ],
        invert_cols=Set(["Missing"])
    )
end

"Similar to `view_gradebook` but specialized for attendance."
function view_attendance(
    gb::Gradebook;
    assignment_filter=nothing,
    student_filter=nothing,
    output_path=joinpath(pwd(), "gradebook", "build", "attendance.html")
)
    df, records, column_labels, row_labels = build_gradebook_display(
        gb;
        assignment_filter=assignment_filter,
        viewing_attendance=true,
        student_filter=student_filter
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
            (matrix, j)->j <= length(records) ? Date(records[j].due) : Date(0),
            (matrix, j)->j <= length(records) ? count(ispresent, df[:, j]) : 0,
            (matrix, j)->j <= length(records) ? count(ispresent, df[:, j])/length(df[:, j]) : 0
        ],
        invert_cols=Set(["Missing", "Absent"])
    )
end
