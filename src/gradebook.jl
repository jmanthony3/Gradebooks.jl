export Gradebook
export grades_post!, grades_sync!
export fill_teams!, withdraw!, reinstate!

using DataFrames, StringDistances

struct Gradebook
    class::Class
    grades::Vector{Grade}
    raw::DataFrame
    penalty::DataFrame
    total::DataFrame
end
function Gradebook(class::Class, grades::Vector{Grade}=[])
    names = [string(a.codename) for a in class.assignments]
    any(a->a.is_group, class.assignments) ? pushfirst!(names, "Team") : nothing
    pushfirst!(names, "ID", "Preferred", "Last", "Email")
    df = DataFrame(zeros(length(class.roster), length(names)), names)
    return Gradebook(class, grades, deepcopy(df), deepcopy(df), deepcopy(df))
end

function find_submission_col(df, assignment; threshold=STRING_MATCH_THRESHOLD)
    headers = string.(names(df))
    target  = sanitize_string(sanitize2codify(assignment.name))

    exact = findall(h -> sanitize_string(h) == target, headers)

    if length(exact) == 1
        return exact[1]
    end

    if length(exact) > 1
        error("Ambiguous submission column for $(assignment.name): $(headers[exact])")
    end

    # fuzzy fallback only if exact matching failed
    scores = map(h -> (h, Levenshtein()(target, sanitize_string(h))), headers)
    best_name, best_dist = sort(scores, by=x -> x[2])[1]

    if best_dist / max(length(target), length(sanitize_string(best_name))) < threshold
        return findfirst(==(best_name), headers)
    end

    error("No reasonable submission column found for $(assignment.name)")
end

function grades_post!(gb::Gradebook, grades::Vector{Grade}; threshold=STRING_MATCH_THRESHOLD)
    nonattendance_idx = filter(!isnothing, indexin(assignments, filter(x->x.category !== :attendance, gb.class.course.assignments)))
    students = gb.class.roster.students
    for grade in filter(g->g.student.enrollment_status == active && g.student.final_grade.category ∉ [FN, W, I], collect(grades))
        gb.raw[occursin.(grade.student.email, gb.raw[!, "Email"]), assignment.codename] .= grade.submission.score.score
        t = grade.submission.submitted - grade.assignment.due
        p = Point(val.assignment.value * late_penalty(t))
        gb.penalty[occursin.(grade.student.email, gb.penalty[!, "Email"]), assignment.codename] .= p
        gb.total[occursin.(grade.student.email, gb.total[!, "Email"]), assignment.codename] .= Point(max(Point(0.0), grade.submission.score.score - p))
        x, y = zero(Point), zero(Point)
        # row = select(gb.total, Cols(x->x.assignment_category !== :attendance, gb.class.course.assignments)=>ByRow(occursin.(grade.student.email, gb.total[!, "Email"])))
        row = gb.total[occursin.(grade.student.email, gb.total[!, "Email"]), :]
        for (val, i) in zip(row[nonattendance_idx], nonattendance_idx)
            x += val
            y += gb.class.course.assignments[i].value
        end
        students[gb.class.student_index.by_id[grade.student.id]] = update(grade.student; final_grade=credit2lettergrade(x, y))
    end
    class = update(gb.class; roster=Roster(students))
    gb = update(gb; class=class)
    return nothing
end

function grades_post!(gb::Gradebook, assignments::Vector{Assignment}, src::String; threshold=STRING_MATCH_THRESHOLD)
    submissions_df = CSV.read(src, DataFrame)
    for assignment in collect(assignments)
        cols = fill(false, ncol(submissions_df))
        cols[find_submission_col(submissions_df, assignment, threshold=threshold)] = true
        submissions_df′ = submissions_df[!, Cols("SIS Login ID", cols)]
        submissions_df′ = DataFrame(Matrix(submissions_df′)[findfirst(!ismissing, submissions_df′[!, "SIS Login ID"]):end, :], names(submissions_df′))
        submissions_df′[!, 1] = convert.(String, submissions_df′[!, 1])
        submissions_df′[!, 2] = convert.(Point, (map(x->ismissing(x) ? 0.0 : x, submissions_df′[!, 2])))

        submissions_dict = Dict{String, Submission}()
        for row in eachrow(submissions_df′)
            try
                get_student(row[1], gb.class.roster)
            catch
            else
                submissions_dict[row[1]] = Submission(assignment.due, Score(Point(row[2]), assignment.value), [Evaluation(try
                    only(assignment.questions)
                catch e
                    if isa(e, ArgumentError)
                        Question("{Completion}", assignment.value)
                    end
                end, Grant(Point(row[2])))])
            end
        end

        grades_post!(gb, map(x->Grade(get_student(x[1], gb.class.roster; threshol=threshold), assignment, x[2]), collect(pairs(submissions_dict))); threshold=threshold)
    end
    return nothing
end

grades_sync!(gb::Gradebook; threshold=STRING_MATCH_THRESHOLD) = grades_post!(gb, gb.grades; threshold=threshold)


include("attendance.jl")


function fill_teams!(gb::Gradebook, teams::Vector{Team})
    for df in [gb.raw, gb.penalty, gb.total]
        for row in eachrow(df)
            # @show row["Email"]
            team_number = "0"
            for team in teams
                # @show map(x->string(split(x.email, "@")[1]), team.students)
                if string(split(row["Email"], "@")[1]) ∈ map(x->string(split(x.email, "@")[1]), team.students)
                    team_number = team.name
                    # @show team_number
                end
            end
            if !isa(team_number, typeof(row["Team"]))
                # gb.raw_score[!, "Team"] = convert.(typeof(team_number), gb.raw_score[!, "Team"])
                # gb.penalty[!, "Team"] = convert.(typeof(team_number), gb.penalty[!, "Team"])
                # gb.total[!, "Team"] = convert.(typeof(team_number), gb.total[!, "Team"])
                df[!, "Team"] = map(string, df[!, "Team"])
                # gb.penalty[!, "Team"] = map(string, gb.penalty[!, "Team"])
                # gb.total[!, "Team"] = map(string, gb.total[!, "Team"])
            end
            row["Team"] = team_number
            # penalty["Team"] = team_number
            # total["Team"] = team_number
        end
    end
    return nothing
end

function withdraw!(gb::Gradebook, student::Union{String, Student}; date::Date = today(), threshold=STRING_MATCH_THRESHOLD)
    if student isa String
        student = get_student(student, gb.class.roster; threshold=threshold)
    end
    student.final_grade = LetterGrade("W")
    student.enrollment_status = withdrawn
    student.withdrawal_date = date

    # Optionally record a W grade automatically
    if haskey(gb.grades_dict, student)  # or however you index grades
        g = gb.grades_dict[student]
        g.submission.score.letter = LetterGrade("W")
    end

    grades_sync!(gb; threshold=threshold)  # or just mark dirty
    return nothing
end

function reinstate!(gb::Gradebook, student::Union{String, Student}; date::Date = today(), threshold=STRING_MATCH_THRESHOLD)
    if student isa String
        student = get_student(student, gb.class.roster; threshold=threshold)
    end
    student.notes[:withdrawal_date] = student.withdrawal_date  # preserve original withdrawal date
    student.notes[:reinstatement_date] = date  # or however you want to track reinstatement
    student.enrollment_status = active
    student.withdrawal_date = nothing
    # Optionally clear the W or let instructor decide
    grades_sync!(gb; threshold=threshold)
    return nothing
end
