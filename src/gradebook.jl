export Gradebook, grades_post!, grades_sync!



using DataFrames, StringDistances



"Single source of truth recording all academic activity for class."
struct Gradebook
    class::Class
    grades::Vector{Grade}
    raw::DataFrame
    penalty::DataFrame
    total::DataFrame
end
function Gradebook(class::Class)
    names = [string(a.codename) for a in class.course.assignments]
    pushfirst!(names, "Who")
    df = DataFrame(zeros(length(class.roster), length(names)), names)
    return Gradebook(class, Grade[], deepcopy(df), deepcopy(df), deepcopy(df))
end

"""
Post grades to the gradebook.

Can post grades for `assignments` from `src` searching for first non-empty row `by` column header.

## Warning
This applies a scalar grade onto the entire assignment and risks erasing evaluation history in gradebook!
"""
function grades_post!(gb::Gradebook, grades::Vector{Grade})
    nonattendance_idx = filter(!isnothing, indexin(assignments, filter(x->x.category !== :attendance, gb.class.course.assignments)))
    students = gb.class.roster.students
    for grade in filter(g->g.student.enrollment_status == Active && (isnothing(g.student.final_grade) || g.student.final_grade ∉ [FN, W, I]), collect(grades))
        rows_idx = occursin.(grade.student, gb.raw[!, "Who"])
        gb.raw[rows_idx, assignment.codename] .= grade
        p = Point(grade.assignment.value * late_penalty(grade))
        gb.penalty[rows_idx, assignment.codename] .= p
        gb.total[rows_idx, assignment.codename] .= Point(max(Point(0.0), grade - p))
        x, y = zero(Point), zero(Point)
        # row = select(gb.total, Cols(x->x.assignment_category !== :attendance, gb.class.course.assignments)=>ByRow(occursin.(grade.student.email, gb.total[!, "Email"])))
        row = gb.total[rows_idx, :]
        for (i, g) in zip(nonattendance_idx, row[nonattendance_idx])
            x += g.submission.score.score.value
            y += gb.class.course.assignments[i].value
        end
        students[gb.class.student_index.by_id[grade.student.id]] = update(grade.student; final_grade=credit2lettergrade(x, y))
    end
    class = update(gb.class; roster=Roster(students))
    gb = update(gb; class=class)
    return nothing
end

function grades_post!(gb::Gradebook, assignments::Vector{Assignment}, src::String; by="ID", threshold=STRING_MATCH_THRESHOLD)
    function find_submission_col(df, assignment; threshold=STRING_MATCH_THRESHOLD)
        headers     = string.(names(df))
        target      = sanitize_string(assignment.name)
        exact       = findall(h->sanitize_string(h) == target, headers)
        if length(exact) == 1
            return only(exact)
        elseif length(exact) > 1
            error("Ambiguous submission column for $(assignment.name): $(headers[exact])")
        else # fuzzy fallback only if exact matching failed
            scores = map(h->(h, Levenshtein()(target, sanitize_string(h))), headers)
            best_name, best_dist = first(sort(scores, by=x->x[2]))
            if best_dist / max(length(target), length(sanitize_string(best_name))) < threshold
                return findfirst(==(best_name), headers)
            end
            matches = map(x->first(x), (sort(scores, by=x->x[2])))
            @error "Assignments with most similar names:" matches
            error("No reasonable submission column found for $(assignment.name)")
        end
    end
    submissions_df = CSV.read(src, DataFrame)
    cols = fill(false, ncol(submissions_df))
    for assignment in collect(assignments)
        cols .= false
        cols[find_submission_col(submissions_df, assignment; threshold=threshold)] = true
        submissions_df′ = submissions_df[!, Cols(by, cols)]
        submissions_df′ = DataFrame(Matrix(submissions_df′)[findfirst(!ismissing, submissions_df′[!, by]):end, :], names(submissions_df′))
        submissions_df′[!, 1] = convert.(String, submissions_df′[!, 1])
        submissions_df′[!, 2] = convert.(Point, (map(x->ismissing(x) ? 0.0 : x, submissions_df′[!, 2])))
        grades = Grade[]
        for row in eachrow(submissions_df′)
            push!(grades, grade(row[1], gb.class.roster, assignment, assignment.due, row[2]; threshold=threshold))
        end
        grades_post!(gb, grades)
    end
    return nothing
end

"Syncs current field value of gb.grades to gradebook."
grades_sync!(gb::Gradebook) = grades_post!(gb, gb.grades)
