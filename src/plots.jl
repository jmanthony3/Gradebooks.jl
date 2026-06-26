export view_gradebook, view_assignment, view_attendance



using DataFrames
using PrettyTables
using Colors
using ColorSchemes



numeric_value(x::Real) = Float64(x)
numeric_value(x::Credit) = x.val
numeric_value(x::Grade) = Float64(x.submission.score.earned)
numeric_value(x) = NaN

function column_bounds(df::DataFrame, j::Int)
    vals = filter(!isnan, map(numeric_value, df[:, j]))
    return isempty(vals) ? (0.0, 1.0) : (minimum(vals), maximum(vals))
end

function color_for_value(v, lo, hi; invert=false)
    nv = numeric_value(v)
    return if isnan(nv)
        "#ffffff"
    elseif lo == hi
        "#e5e5e5"
    else
        s = clamp((nv - lo) / (hi - lo), 0, 1)
        if invert
            s = 1 - s
        end
        "#" * hex(get(colorschemes[:RdYlGn], s))
    end
end

function per_column_highlighters(df::DataFrame; invert_cols=Set{String}())
    df_names = names(df)
    hls = HtmlHighlighter[]
    for j in 1:ncol(df)
        colname = df_names[j]
        lo, hi = column_bounds(df, j)
        inv = colname ∈ invert_cols
        push!(hls, HtmlHighlighter(
            (data, i, jj) -> jj == j,
            (data, i, jj) -> begin
                style = color_for_value(data[i, jj], lo, hi; invert=inv)
                ["background-color" => style]
            end
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

    return p
end


function build_gradebook_display(gb::Gradebook;
    assignment_filter=nothing,
    student_filter=nothing
)
    assignments = !isnothing(assignment_filter) ? gb.class.course.assignments[assignment_filter] : gb.class.course.assignments[findall(x->x.category != CategoryAttendance, gb.class.course.assignments)]
    students_idx = !isnothing(student_filter) ? student_filter : (1:nrow(gb.total))

    cols = map(a->a.codename, assignments)
    df_raw = gb.raw[students_idx, Cols(cols...)]
    df_penalty = gb.penalty[students_idx, Cols(cols...)]
    df_total = gb.total[students_idx, Cols(cols...)]

    df_total.Raw = if all(x->x.category == CategoryAttendance, assignments)
        map(eachrow(df_raw)) do row
            count(==(Present), row)
        end
    else
        map(eachrow(df_raw)) do row
            sum(row[c] for c in cols)
        end
    end

    df_total.Penalty = map(eachrow(df_penalty)) do row
        sum(row[c] for c in cols)
    end

    df_total.Total = if all(x->x.category == CategoryAttendance, assignments)
        df_total.Penalty
    else
        df_total.Raw - df_total.Penalty
    end

    total_possible = all(x->x.category == CategoryAttendance, assignments) ? length(map(x->x.category == CategoryAttendance, gb.class.course.assignments)) : mapreduce(a->a.value, +, assignments; init=zero(Point))
    df_total.Percent = map(df_total.Raw) do t
        Percent(t / total_possible)
    end

    if !all(x->x.category == CategoryAttendance, assignments)
        df_total.Letter = map(df_total.Percent) do p
            credit2lettergrade(p)
        end

        df_total.Missing = map(df_total.Total) do t
            Point(total_possible.val - t.val)
        end
    end

    df_total.Absent = map(eachrow(gb.penalty[students_idx, Cols(map(a->a.codename, filter(x->x.category != CategoryAttendance, gb.class.course.assignments))...)])) do t
        count(==(Absent), t)
    end

    if !all(x->x.category == CategoryAttendance, assignments)
        df_total.Extension = map(gb.class.roster.students[students_idx]) do student
            get(student.notes, "Extension", "")
        end

        df_total.Accommodation = map(gb.class.roster.students[students_idx]) do student
            get(student.notes, "Accommodation", "")
        end
    end

    column_labels = [
        names(df_total),
        map(x->repr(typeof(x).parameters[1])[9:end], assignments),
        map(x->typeof(x).parameters[2], assignments),
        map(x->typeof(x).types[2], assignments),
    ]

    data = [
        map(s->!isempty(s.name_preferred) ? s.name_preferred : s.name_given, gb.class.roster.students[students_idx]), # Preferred
        map(s->s.name_family, gb.class.roster.students[students_idx]), # Last
        map(s->s.id, gb.class.roster.students[students_idx]), # ID
        map(s->s.email, gb.class.roster.students[students_idx]), # Email
    ]
    if !isempty(gb.class.teams)
        team_names = String[]
        for student in gb.class.roster.students[students_idx]
            for team in gb.class.teams
                if student ∈ team.roster.students
                    push!(team_names, team.name)
                end
            end
        end
        push!(data, team_names) # Team
    end

    return df_total, assignments, column_labels, [join(collect(row), " ") for row in zip(data...)]
end

function leaf_items(item)
    if hasproperty(item, :parts) && !isnothing(item.parts) && !isempty(item.parts)
        return vcat((leaf_items(p) for p in item.parts)...)
    else
        return [item]
    end
end

function leaf_score(item, evs, parent_value)
    ev = findfirst(e -> e.item === item, evs)
    return if isnothing(ev)
        Point(0.0)
    else
        δ = ev.mark.delta
        if isa(δ, Point)
            δ
        elseif isa(δ, Percent)
            base = if isa(item, Question)
                get_leafvalue(item, parent_value)
            else
                parent_value
            end
            Point(base.val * δ.val)
        else
            Point(0.0)
        end
    end
end

function build_assignment_display(grades::Vector{Grade}, assignment::Assignment; student_filter=nothing, teams=Team[])
    students_idx = !isnothing(student_filter) ? student_filter : (1:nrow(gb.total))
    grades = grades[students_idx]
    df = DataFrame(
        # Preferred = map(g -> !isempty(g.student.person.name_preferred) ? g.student.person.name_preferred : g.student.person.name_given, grades),
        # Last = map(g -> g.student.person.name_family, grades),
        # ID = map(g -> g.student.id, grades),
        # Email = map(g -> g.student.email, grades),
        # # Team = map(g -> getproperty(g.student, :team, ""), grades)
    )

    # collect all leaf nodes once
    all_leaves = vcat((leaf_items(q) for q in assignment.questions)...)

    # add one column per leaf
    for leaf in all_leaves
        df[!, leaf.codename] = map(grades) do g
            # g.submission.evaluations should be the leaf-level evaluations
            leaf_score(leaf, g.submission.evaluations, assignment.value)
        end
    end

    # summary columns
    df.Total = map(g -> g.submission.score.score, grades)
    df.Percent = map(g -> g.submission.score.percent, grades)
    df.Letter = map(g -> g.submission.score.letter.string, grades)
    df.Missing = map(g -> assignment.value - g.submission.score.score.earned, grades)

    column_labels = [
        names(df_total),
        map(x->repr(typeof(x).parameters[1])[9:end], assignments),
        map(x->typeof(x).parameters[2], assignments),
        map(x->typeof(x).types[2], assignments),
    ]

    data = [
        map(s->!isempty(s.name_preferred) ? s.name_preferred : s.name_given, gb.class.roster.students[students_idx]), # Preferred
        map(s->s.name_family, gb.class.roster.students[students_idx]), # Last
        map(s->s.id, gb.class.roster.students[students_idx]), # ID
        map(s->s.email, gb.class.roster.students[students_idx]), # Email
    ]
    if !isempty(gb.class.teams)
        team_names = String[]
        for student in gb.class.roster.students[students_idx]
            for team in gb.class.teams
                if student ∈ team.roster.students
                    push!(team_names, team.name)
                end
            end
        end
        push!(data, team_names) # Team
    end

    return df, all_leaves, column_labels, [join(collect(row), " ") for row in zip(data...)]
end


"View gradebook for entire class or subset according to index filter of assignments or students."
function view_gradebook(
    gb::Gradebook;
    assignment_filter=nothing,
    student_filter=nothing,
    output_path=joinpath(pwd(), "gradebook", "build", "gradebook.html")
)
    df, assignments, column_labels, row_labels = build_gradebook_display(gb;
        assignment_filter=assignment_filter,
        student_filter=student_filter
    )

    return render_table(
        df;
        title="$(gb.class.codename_long): $(gb.class.course.name)",
        subtitle="Class Gradebook",
        output_path=output_path,
        column_labels=column_labels,
        row_labels=row_labels,
        summary_row_labels=["Worth", "Due", "Average (Point)", "Average (Percent)"],
        summary_rows=[
            (matrix, j)->assignments[j].value,
            (matrix, j)->assignments[j].due,
            (matrix, j)->Point.(sum(df[:, j])/length(df[:, j])),
            (matrix, j)->Percent.(Point.(sum(df[:, j])/length(df[:, j]))/assignments[j].value)
        ],
        invert_cols=Set(["Missing", "Penalty", "Absent"])
    )
end

"View detailed breakdown of assignment performance across entire class or subset according to index filter of students."
function view_assignment(
    gb::Gradebook,
    assignment::Assignment;
    student_filter=nothing,
    output_path=joinpath(pwd(), "gradebook", "build", "assignment.html")
)
    df, items, column_labels, row_labels = build_assignment_display(gb.total[!, assignment.codename], assignment; student_filter=student_filter, teams=gb.teams)

    return render_table(
        df;
        title="$(assignment.name) ($(assignment.value) points)",
        subtitle="Assignment Breakdown",
        output_path=output_path,
        column_labels=column_labels,
        row_labels=row_labels,
        summary_row_labels=["Worth", "Average (Point)", "Average (Percent)"],
        summary_rows=[
            (matrix, j)->items[j].value,
            (matrix, j)->Point.(sum(df[:, j])/length(df[:, j])),
            (matrix, j)->Percent.(Point.(sum(df[:, j])/length(df[:, j]))/items[j].value)
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
        assignment_filter=!isnothing(assignment_filter) ? findall(x->x.category == CategoryAttendance, gb.class.course.assignments) : assignment_filter,
        student_filter=student_filter
    )

    render_table(
        df;
        title="$(gb.class.course.name)",
        subtitle="Attendance",
        output_path=output_path,
        column_labels=column_labels,
        row_labels=row_labels,
        summary_row_labels=["Due", "Present", "Present (Average)"],
        summary_rows=[
            (matrix, j)->Date.(records[j].due),
            (matrix, j)->count(==(Present), df[:, j]),
            (matrix, j)->Point.(sum(df[:, j])/length(df[:, j]))
        ],
        invert_cols=Set(["Missing", "Absent"])
    )
end
