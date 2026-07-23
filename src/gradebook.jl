export Gradebook
public post_grade!
export grades_post!, grades_sync!



using DataFrames, StringDistances



"Single source of truth recording all academic activity for class."
mutable struct Gradebook <: AbstractGradebookNode
    class::Class
    grades::Vector{Grade}
    raw::DataFrame
    penalty::DataFrame
    total::DataFrame
end
function Gradebook(class::Class)
    df_raw, df_penalty, df_total = DataFrame(), DataFrame(), DataFrame()
    for i ∈ 1:1:length(class.course.assignments)
        insertcols!(df_raw, class.course.assignments[i].codename=>Vector{Grade}(undef, length(class.roster)))
        # insertcols!(df_penalty, class.course.assignments[i].codename=>Vector{Point}(undef, length(class.roster)))
        insertcols!(df_penalty, class.course.assignments[i].codename=>fill(Point(0.0), length(class.roster)))
        insertcols!(df_total, class.course.assignments[i].codename=>Vector{Grade}(undef, length(class.roster)))
    end
    for i ∈ 1:1:length(class.lectures)
        insertcols!(df_raw, class.lectures[i].codename=>Vector{AttendanceRecord}(undef, length(class.roster)))
        # insertcols!(df_penalty, class.lectures[i].codename=>Vector{Point}(undef, length(class.roster)))
        insertcols!(df_penalty, class.lectures[i].codename=>fill(Point(0.0), length(class.roster)))
        insertcols!(df_total, class.lectures[i].codename=>Vector{AttendanceRecord}(undef, length(class.roster)))
    end
    return Gradebook(class, Grade[], df_raw, df_penalty, df_total)
end

get_student(identifier::String, gb::Gradebook; threshold=STRING_MATCH_THRESHOLD) = get_student(identifier, gb.class.roster; threshold=threshold)

"Posts `grade` to gradebook."
function post_grade!(gb::Gradebook, grade::Grade)
    i = gb.class.roster.by_id[grade.student.person.id]
    gb.raw[i, grade.assignment.codename] = grade
    p = Point(grade.assignment.value * latepenalty(grade))
    gb.penalty[i, grade.assignment.codename] = p
    gb.total[i, grade.assignment.codename] = max(grade - grade.submission.score.earned, grade - p)
    return nothing
end

"""
Post grades to the gradebook.

Can post grades for `assignments` from `src` searching for first non-empty row `by` column header.

## Warning
This applies a scalar grade onto the entire assignment and risks erasing evaluation history in gradebook!
"""
function grades_post!(gb::Gradebook, grades::Vector{Grade})
    gb.grades = grades
    students = gb.class.roster.students
    for grade ∈ filter(g->isactive(g.student) && (isnothing(g.student.final_grade) || all(g.student.final_grade .!= [FN, W, I])), grades)
        i, j = gb.class.roster.by_id[grade.student.person.id], length(gb.class.course.assignments)
        post_grade!(gb, grade)
        x, y = zero(Point), zero(Point)
        for (_, g) ∈ enumerate(gb.total[i, :][filter(k->isassigned(gb.raw[!, k], i), 1:j)])
            x += g.submission.score.earned.value
            y += g.assignment.value
        end
        students[i] = update(grade.student; final_grade=credit2lettergrade(x, y))
    end
    gb.class = update(gb.class; roster=Roster(students))
    return nothing
end

function grades_post!(gb::Gradebook, assignments::Vector{Assignment}, src::String; by="ID", threshold=STRING_MATCH_THRESHOLD)
    function find_submission_col(df, assignment; threshold=STRING_MATCH_THRESHOLD)
        headers     = string.(names(df))
        target      = string_sanitize(assignment.name)
        exact       = findall(h->string_sanitize(h) == target, headers)
        if length(exact) == 1
            return only(exact)
        elseif length(exact) > 1
            error("Ambiguous submission column for $(assignment.name): $(headers[exact])")
        else # fuzzy fallback only if exact matching failed
            scores = map(h->(h, Levenshtein()(target, string_sanitize(h))), headers)
            best_name, best_dist = first(sort(scores, by=x->x[2]))
            if best_dist / max(length(target), length(string_sanitize(best_name))) < threshold
                return findfirst(==(best_name), headers)
            end
            matches = map(x->first(x), (sort(scores, by=x->x[2])))
            @error "Assignments with most similar names:" matches
            error("No reasonable submission column found for $(assignment.name)")
        end
    end
    submissions_df = CSV.read(src, DataFrame)
    cols = fill(false, ncol(submissions_df))
    for assignment ∈ assignments
        cols .= false
        cols[find_submission_col(submissions_df, assignment; threshold=threshold)] = true
        submissions_df′ = submissions_df[!, Cols(by, cols)]
        submissions_df′ = DataFrame(Matrix(submissions_df′)[findfirst(!ismissing, submissions_df′[!, by]):end, :], names(submissions_df′))
        submissions_df′[!, 1] = convert.(String, submissions_df′[!, 1])
        submissions_df′[!, 2] = convert.(Point, (map(x->ismissing(x) ? 0.0 : (isa(x, String) ? parse(x, Float64) : x), submissions_df′[!, 2])))
        grades = Grade[]
        for row ∈ eachrow(submissions_df′)
            push!(grades, grade(row[1], gb.class.roster, assignment, assignment.due, row[2]; threshold=threshold))
        end
        grades_post!(gb, grades)
    end
    return nothing
end

"Syncs current field value of `gb.grades` to gradebook."
grades_sync!(gb::Gradebook) = grades_post!(gb, gb.grades)
