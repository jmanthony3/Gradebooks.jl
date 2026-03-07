using Gradebooks, Tachikoma, Match
@tachikoma_app

# include("gradebook.jl")

@kwdef mutable struct GradebookModel <: Model
    quit::Bool = false
    gradebook::Gradebook = gb
    attendance::Gradebook = att
end

should_quit(m::GradebookModel) = m.quit

function grade!(m::GradebookModel)
    # include("gradebook.jl")
end

function update!(m::GradebookModel, evt::KeyEvent)
    @match (evt.key, evt.char) begin
        (:char, 'q') || (:escape, _) => (m.quit = true)
        # (:char, 'g') || (:enter, _)  => grade!(m)
        # (:char, 'b') || (:char, ' ') => bank!(m)
        _                            => nothing
    end
end

function view(m::GradebookModel, f::Frame)
    # m.tick += 1
    buf = f.buffer

    # Border color reflects game state
    # border_style = m.busted ? tstyle(:error) :
    #                m.turn_total > 20 ? tstyle(:warning) :
    border_style = tstyle(:border)
    inner = render(Block(title="Gradebook", border_style=border_style), f.area, buf)

    rows = split_layout(
        Layout(Vertical, [Fixed(1), Fixed(1), Fixed(5), Fixed(1), Fill()]),
        inner)
    length(rows) < 5 && return

    # Row 1: score labels
    set_string!(buf, rows[1].x, rows[1].y,
        "$(m.gradebook.who.codename_long): $(m.gradebook.who.course.name)", tstyle(:primary, bold=true))

    render(Table(names(m.gradebook.total), map(y->["$z" for z in y], eachrow(m.gradebook.total))), f.area, buf)

    # Status bar pinned to the bottom edge of the terminal
    render(StatusBar(
        left=[Span("  [r]oll  ", tstyle(:accent)),
              Span("[b]ank  ", tstyle(:success))],
        right=[Span("[q]uit ", tstyle(:text_dim))],
    ), Rect(f.area.x, bottom(f.area), f.area.width, 1), buf)
end

app(GradebookModel())