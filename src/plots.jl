export view_assignment, view_gradebook, view_attendance

using DataFrames
using PrettyTables
using Colors
using ColorSchemes

const BASE_METADATA = ["ID", "Preferred", "Last", "Team", "Email"]

# --- display helpers ---------------------------------------------------------

# normalize anything we might display
numeric_value(x) = x isa Point || x isa Percent ? x.val :
                   x isa Number ? Float64(x) :
                   NaN

function column_bounds(df::DataFrame, j::Int)
    vals = filter(!isnan, map(numeric_value, df[:, j]))
    return isempty(vals) ? (0.0, 1.0) : (minimum(vals), maximum(vals))
end

function color_for_value(v, lo, hi; invert=false)
    nv = numeric_value(v)
    isnan(nv) && return "#ffffff"
    lo == hi && return "#e5e5e5"

    s = clamp((nv - lo) / (hi - lo), 0, 1)
    invert && (s = 1 - s)
    return "#" * hex(get(colorschemes[:RdYlGn], s))
end

function per_column_highlighters(df::DataFrame; invert_cols=Set{String}())
    hls = HtmlHighlighter[]

    for j in 1:ncol(df)
        colname = names(df)[j]
        lo, hi = column_bounds(df, j)
        inv = colname in invert_cols

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
    outpath="",
    row_labels=nothing,
    column_labels=nothing,
    summary_rows=nothing,
    invert_cols=Set{String}(),
    style=nothing
)
    hls = per_column_highlighters(df; invert_cols=invert_cols)

    p = PrettyTable(
        df;
        title=title,
        subtitle=subtitle,
        row_labels=row_labels,
        column_labels=column_labels,
        summary_rows=summary_rows,
        highlighters=hls,
        style=style === nothing ? HtmlTableStyle() : style,
        backend=:html,
        stand_alone=true
    )

    mkpath(dirname(outpath))
    open(outpath, "w") do io
        write(io, repr(p))
    end

    return p
end

# --- common display builders -------------------------------------------------

function build_gradebook_display(gb::Gradebook, assignments::Vector{Assignment};
    student_filter=nothing,
    assignment_filter=nothing
)
    # choose assignment columns
    selected = assignment_filter === nothing ? assignments : assignments[assignment_filter]

    # choose student rows
    row_idx = student_filter === nothing ? (1:nrow(gb.total)) : student_filter

    cols = vcat(BASE_METADATA, map(a -> a.codename, selected))
    df = gb.total[row_idx, Cols(cols...)]

    # derived columns
    df.Total = map(eachrow(df)) do row
        sum(row[c] for c in cols[6:end])  # skip metadata columns
    end

    total_possible = mapreduce(a -> a.value, +, selected; init=Point(0.0))
    df.Percent = map(df.Total) do t
        Percent(t / total_possible)
    end

    df.Letter = map(df.Percent) do p
        credit2letter(p)
    end

    df.Missing = map(df.Total) do t
        Point(total_possible.val - t.val)
    end

    return df
end

function leaf_items(item)
    if hasproperty(item, :parts) && !isnothing(item.parts) && !isempty(item.parts)
        return vcat((leaf_items(p) for p in item.parts)...)
    else
        return [item]
    end
end

function leaf_score(item, evs, parent_value)
    # find an exact evaluation for this leaf item
    ev = findfirst(e -> e.item === item, evs)
    isnothing(ev) && return Point(0.0)

    δ = ev.mark.delta
    if δ isa Point
        return δ
    elseif δ isa Percent
        # normalize percent to an absolute point value using the item's base
        base = if item isa Question
            absolute_question_points(item, parent_value)
        else
            parent_value
        end
        return Point(base.val * δ.val)
    else
        return Point(0.0)
    end
end

function build_assignment_display(grades::Vector{Grade}, assignment::Assignment)
    df = DataFrame(
        ID = map(g -> g.student.id, grades),
        Preferred = map(g -> isempty(g.student.person.name_preferred) ? g.student.person.name_given : g.student.person.name_preferred, grades),
        Last = map(g -> g.student.person.name_family, grades),
        Team = map(g -> getproperty(g.student, :team, ""), grades),
        Email = map(g -> g.student.email, grades)
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
    df.Letter = map(g -> g.submission.score.letter, grades)
    df.Missing = map(g -> assignment.value - g.submission.score.score, grades)

    return df
end

# --- view wrappers -----------------------------------------------------------

function view_gradebook(
    gb::Gradebook,
    assignments::Vector{Assignment};
    student_filter=nothing,
    assignment_filter=nothing,
    outpath=joinpath(pwd(), "gradebook", "build", "gradebook.html")
)
    df = build_gradebook_display(
        gb, assignments;
        student_filter=student_filter,
        assignment_filter=assignment_filter
    )

    render_table(
        df;
        title="$(gb.class.course.name)",
        subtitle="Class Gradebook",
        outpath=outpath,
        invert_cols=Set(["Missing", "Penalty", "Absent"])
    )
end

function view_assignment(
    grades::Vector{Grade},
    assignment::Assignment;
    outpath=joinpath(pwd(), "gradebook", "build", "assignment.html")
)
    df = build_assignment_display(grades, assignment)

    render_table(
        df;
        title="$(assignment.name) ($(assignment.value) points)",
        subtitle="Assignment Detail",
        outpath=outpath,
        invert_cols=Set(["Missing"])
    )
end

function view_attendance(
    gb::Gradebook,
    lectures::Vector{Assignment};
    student_filter=nothing,
    assignment_filter=nothing,
    outpath=joinpath(pwd(), "gradebook", "build", "attendance.html")
)
    df = build_gradebook_display(
        gb, lectures;
        student_filter=student_filter,
        assignment_filter=assignment_filter
    )

    render_table(
        df;
        title="$(gb.class.course.name)",
        subtitle="Attendance",
        outpath=outpath,
        invert_cols=Set(["Missing", "Absent"])
    )
end
