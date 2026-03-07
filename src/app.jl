using Gradebooks, Tachikoma, Match
@tachikoma_app

@kwdef mutable struct GradebookModel <: Model
    quit::Bool = false
    gradebook::Gradebook = Gradebook()
    attendance::Gradebook = Gradebook()
end

should_quit(m::GradebookModel) = m.quit

# function grade!(m::GradebookModel)
#     include("gradebook.jl")
# end

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
    total = m.score + m.turn_total
    set_string!(buf, rows[1].x, rows[1].y,
        "Score: $(m.score)", tstyle(:primary, bold=true))
    turn_style = m.busted ? tstyle(:error, bold=true) :
                 m.turn_total > 15 ? tstyle(:warning, bold=true) :
                 tstyle(:accent)
    turn_label = m.busted ? "BUST!" : "Turn: $(m.turn_total)"
    set_string!(buf, rows[1].x + rows[1].width ÷ 2, rows[1].y,
        turn_label, turn_style)

    # Row 2: progress gauge toward 100
    gauge_style = total >= 100 ? tstyle(:success) :
                  total >= 60  ? tstyle(:warning) :
                  m.busted     ? tstyle(:error) :
                  tstyle(:primary)
    render(Gauge(clamp(total / 100, 0, 1);
        filled_style=gauge_style,
        empty_style=tstyle(:text_dim, dim=true)), rows[2], buf)

    # Row 3: large die face for the most recent roll
    if !isempty(m.rolls)
        face = m.rolls[end]
        art = DIE_ART[face]
        die_rect = center(rows[3], 7, length(art))
        ds = m.busted ? tstyle(:error, bold=true) : die_color(face)
        for (row, line) in enumerate(art)
            set_string!(buf, die_rect.x, die_rect.y + row - 1, line, ds)
        end
    else
        msg = "Press [r] to roll"
        r = center(rows[3], length(msg), 1)
        set_string!(buf, r.x, r.y, msg, tstyle(:text_dim))
    end

    # Row 4: small unicode dice for previous rolls this turn
    die_faces = ['⚀', '⚁', '⚂', '⚃', '⚄', '⚅']
    if length(m.rolls) > 1
        hist = @view m.rolls[1:end-1]
        origin = center(rows[4], length(hist) * 2 - 1, 1)
        for (i, r) in enumerate(hist)
            set_char!(buf, origin.x + (i - 1) * 2, origin.y, die_faces[r], die_color(r))
        end
    end

    # Row 5: turn history — banked amounts and busts
    if !isempty(m.turns)
        dx = rows[5].x
        for (i, t) in enumerate(m.turns)
            label = t == 0 ? "✗" : "+$t"
            s = t == 0  ? tstyle(:error) :
                t >= 15 ? tstyle(:success, bold=true) :
                tstyle(:accent)
            set_string!(buf, dx, rows[5].y, label, s)
            dx += length(label) + 1
            dx >= rows[5].x + rows[5].width && break
        end
    end

    # Status bar pinned to the bottom edge of the terminal
    render(StatusBar(
        left=[Span("  [r]oll  ", tstyle(:accent)),
              Span("[b]ank  ", tstyle(:success))],
        right=[Span("[q]uit ", tstyle(:text_dim))],
    ), Rect(f.area.x, bottom(f.area), f.area.width, 1), buf)
end

run() = app(GradebookModel())