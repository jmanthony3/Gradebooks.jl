using Tachikoma, Match
using DataFrames, Tables
# using Gradebooks  # your package
@tachikoma_app

@kwdef mutable struct GradebookApp <: Model
    quit::Bool = false
    dirty::Bool = false                  # triggers auto-save
    current_dir::String = pwd()
    metadata::Dict{String,Any} = Dict()
    gradebook::DataFrame = DataFrame()
    current_tab::Int = 1                 # controlled by TabBar
    selected_students::Vector{Int} = Int[]  # row indices for subset trends
    current_assignment::String = ""
    rubric::String = ""                  # or Dict for structured rubric
    # widgets (rebuilt in view or on data change)
    tabbar::TabBar = TabBar(["Overview", "Trends", "Grade Entry", "Reports"])
    df_table::DataTable = DataTable([DataColumn("empty", String[])])
    trend_chart::Chart = Chart([])
    # add more as needed (forms, modals, etc.)
    tasks::TaskQueue = TaskQueue()
end

should_quit(m::GradebookApp) = m.quit

# ───── AUTO-LOAD / BOOT LOGIC ─────
function init!(m::GradebookApp, ::Terminal)
    # Auto-load if we booted from a class directory (customize the marker file)
    marker = joinpath(m.current_dir, ".gradebook")
    if isfile(marker)
        spawn_task!(m.tasks, :load) do
            Gradebooks.load_gradebook(m.current_dir)  # returns (meta, df)
        end
    end
end

function update!(m::GradebookApp, evt::TaskEvent)
    evt.id == :load || return
    if evt.value isa Tuple
        m.metadata, m.gradebook = evt.value
        m.df_table = build_df_table(m.gradebook)
        m.dirty = false
    end
    # similar for :save task
end

function update!(m::GradebookApp, evt::KeyEvent)
    if evt.key == :escape
        m.quit = true
        return
    end

    # Tab navigation
    if handle_key!(m.tabbar, evt)
        m.current_tab = value(m.tabbar)
        return
    end

    # Per-tab delegation (expand as you add widgets)
    if m.current_tab == 1  # Overview
        handle_key!(m.df_table, evt)
    elseif m.current_tab == 2  # Trends
        # handle subset selection list here
    elseif m.current_tab == 3  # Grade Entry
        # delegate to form / student list
    end

    # Global shortcuts
    if evt.key == :char && evt.char == 's'  # manual Submit/Save
        save_state!(m)
    end

    # Mark dirty after edits (you'll add this in grade-entry logic)
    m.dirty && save_state!(m)  # auto-save on major changes
end

# ───── SAVE (auto or on Submit) ─────
function save_state!(m::GradebookApp)
    m.dirty || return
    spawn_task!(m.tasks, :save) do
        Gradebooks.save_gradebook(m.current_dir, m.metadata, m.gradebook)
    end
    m.dirty = false
end

# ───── VIEW (main layout with tabs + sidebars) ─────
function view(m::GradebookApp, f::Frame)
    area = f.area
    buf = f.buffer

    # Top TabBar (always visible)
    tab_rect = Rect(area.x, area.y, area.width, 1)
    render(m.tabbar, tab_rect, buf)

    # Main content area (below tabbar)
    main_area = Rect(area.x, area.y+1, area.width, area.height-1)

    # Persistent left sidebar: Metadata
    meta_rect, rest = split_layout(Layout(Horizontal, [Fixed(25), Fill()]), main_area)
    render(Block(title="Class Metadata", border_style=tstyle(:border)),
           meta_rect, buf)
    # Fill metadata (Paragraph or simple text)
    meta_text = join(["$(k): $(v)" for (k,v) in m.metadata], "\n")
    render(Paragraph(meta_text; block=nothing), inner_rect(meta_rect), buf)

    # Right sidebar changes per tab (assignment + rubric when on Grade Entry)
    if m.current_tab == 3
        right_w = 30
        main_rect, right_rect = split_layout(Layout(Horizontal, [Fill(), Fixed(right_w)]), rest)
        render(Block(title="Assignment: $(m.current_assignment)", border_style=tstyle(:accent)),
               right_rect, buf)
        render(Paragraph(m.rubric), inner_rect(right_rect), buf)
    else
        main_rect = rest
    end

    # Main tab content
    if m.current_tab == 1  # Overview
        render(m.df_table, main_rect, buf)
    elseif m.current_tab == 2  # Trends
        # Whole class + subset
        render(m.trend_chart, main_rect, buf)
        # Add SelectableList for subset below or in a split
    elseif m.current_tab == 3  # Grade Entry
        # Placeholder: replace with Form + SelectableList of students
        render(Paragraph("Grade entry form here\n(student selector + rubric inputs)", 
               block=Block(title="Enter Grades")), main_rect, buf)
    elseif m.current_tab == 4  # Reports
        render(Paragraph("Select report type:\n• Academic Misconduct\n• Defense of Grade",
               block=Block(title="Reports")), main_rect, buf)
        # Buttons trigger report generation
    end

    # Status bar (bottom)
    render(StatusBar(
        left=[Span(" [s]ave ", tstyle(:success)), Span(" [q]uit ", tstyle(:error))],
        right=[Span("Tab $(m.current_tab)/4", tstyle(:text_dim))]
    ), Rect(area.x, area.y+area.height-1, area.width, 1), buf)
end

# ───── HELPERS ─────
function build_df_table(df::DataFrame)
    DataTable(df;  # direct DataFrame support!
        block=Block(title="Gradebook"),
        selected=1
    )
end

# Example trend builder (call when tab switches or data changes)
function update_trends!(m::GradebookApp)
    # Compute class averages per assignment (adapt to your columns)
    assignments = filter(c -> c != "Student", names(m.gradebook))
    averages = [mean(skipmissing(m.gradebook[!, a])) for a in assignments]
    series = [DataSeries(averages; label="Class Avg", style=tstyle(:primary))]
    
    # Subset if selected
    if !isempty(m.selected_students)
        subset_avg = [mean(skipmissing(m.gradebook[m.selected_students, a])) for a in assignments]
        push!(series, DataSeries(subset_avg; label="Selected", style=tstyle(:accent)))
    end
    
    m.trend_chart = Chart(series; block=Block(title="Performance Trends"))
end

# Report generators (expand with templates)
function generate_report(m::GradebookApp, type::Symbol, student_idx::Int)
    student = m.gradebook[student_idx, :]
    path = joinpath(m.current_dir, "$(student.Student)_$(type).txt")
    open(path, "w") do io
        if type == :misconduct
            println(io, "Academic Misconduct Report\nStudent: $(student.Student)\n...")
        elseif type == :defense
            println(io, "Grade Defense Report\nStudent: $(student.Student)\nReason: ...")
        end
    end
    # Optional: Modal("Report saved to $path")
end