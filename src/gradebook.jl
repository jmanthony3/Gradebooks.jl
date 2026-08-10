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

function get_assignments(gb::Gradebook; assignment_filter=nothing, viewing_attendance=false)
    return if viewing_attendance
        !isnothing(assignment_filter) ? gb.class.lectures[assignment_filter] : gb.class.lectures
    else
        !isnothing(assignment_filter) ? gb.class.course.assignments[assignment_filter] : gb.class.course.assignments
    end
end

function get_students(gb::Gradebook; student_filter=nothing)
    return if !isnothing(student_filter)
        sort(if isa(student_filter, Vector{Int})
            student_filter
        elseif isa(student_filter, Roster)
            map(s->gb.class.roster.by_id[s.person.id], student_filter.students)
        elseif isa(student_filter, Vector{Student})
            map(s->gb.class.roster.by_id[s.person.id], student_filter)
        elseif isa(student_filter, Vector{String})
            filter(!isnothing, map(s->try
                gb.class.roster.by_id[get_student(s, gb.class.roster).person.id]
            catch
                nothing
            end, student_filter))
        else
            error("Could not insert student filter which must be provided as roster or vector of integers, students, or string identifiers")
        end)
    else
        (1:nrow(gb.total))
    end
end

function get_rawpoints(df::DataFrame, df_safe::DataFrame; viewing_attendance=false)
    return map(map(i -> begin
        row = collect(skipmissing([df_safe[i, j] for j in 1:ncol(df)]))
        viewing_attendance ? count(ispresent, row) : mapreduce(r -> r.submission.score.earned, +, row; init=Point(0.0))
    end, 1:nrow(df))) do row
        row
    end
end

function get_penaltypoints(df::DataFrame, df_penalty::DataFrame, students_idx::Vector{Int}; viewing_attendance=false, assignment_filter=nothing)
    return map(eachrow(!viewing_attendance && isnothing(assignment_filter) ? df[students_idx, :] : df_penalty)) do row
        sum(row)
    end
end

function get_totalpoints(df::DataFrame; viewing_attendance=false)
    return if viewing_attendance
        df.Penalty
    else
        df.Raw - df.Penalty
    end
end

function get_totalpossible(assignments::Vector{Assignment}; viewing_attendance=false)
    return viewing_attendance ? length(assignments) : mapreduce(a->a.value.value, +, assignments; init=0.0)
end

function get_percent(df::DataFrame, total_possible::Real)
    return map(df.Total) do t
        Percent(t.value / total_possible; normalize=false)
    end
end

function get_lettergrade(df::DataFrame)
    return map(df.Percent) do p
        credit2lettergrade(p)
    end
end

function get_gpa(df::DataFrame)
    return map(df.Letter) do ℓ
        ℓ.quality_points
    end
end

function get_missing(df::DataFrame, total_possible::Float64)
    return map(df.Total) do t
        Point(total_possible - t.value)
    end
end

function get_absent(gb::Gradebook, students_idx::Vector{Int})
    return map(map(i->gb.raw[i, filter(j->isassigned(Matrix(gb.raw), i, j), 1:ncol(gb.raw))], students_idx)) do row
        count(isabsent, row)
    end
end

function get_extension(students_idx::Vector{Int}, roster::Roster)
    return map(roster.students[students_idx]) do student
        get(student.notes, "Extension", length(student.extension_history) > 0 ? string(length(student.extension_history)) : "")
    end
end

function get_accommodation(students_idx::Vector{Int}, roster::Roster)
    return map(roster.students[students_idx]) do student
        get(student.notes, "Accommodation", !isempty(student.accommodations) ? map(a->a.type, student.accommodations) : "")
    end
end

function Base.getproperty(gb::Gradebook, sym::Symbol)
    if sym == :class || sym == :grades || sym == :raw || sym == :penalty || sym == :total
        return getfield(gb, sym)
    elseif sym == :raw_vector || sym == :penalty_vector || sym == :total_vector || sym == :percent_vector || sym == :letter_vector || sym == :gpa_vector || sym == :missing_vector || sym == :absent_vector || sym == :extension_vector || sym == :accommodation_vector
        assignments = getfield(getfield(getfield(gb, :class), :course), :assignments)
        students_idx = (1:nrow(getfield(gb, :total)))

        cols = map(a->a.codename, assignments)
        safe_raw = sanitize_dataframe(getfield(gb, :raw))
        safe_penalty = sanitize_dataframe(getfield(gb, :penalty))
        safe_total = sanitize_dataframe(getfield(gb, :total))
        df_raw = safe_raw[students_idx, Cols(cols...)]
        df_penalty = safe_penalty[students_idx, Cols(cols...)]
        df_total = safe_total[students_idx, Cols(cols...)]

        df_total.Raw = get_rawpoints(df_raw, safe_raw)
        df_total.Penalty = get_penaltypoints(getfield(gb, :penalty), df_penalty, [students_idx...])
        df_total.Total = get_totalpoints(df_total)

        total_possible = get_totalpossible(assignments)
        df_total.Percent = get_percent(df_total, total_possible)

        df = DataFrame(
            Raw = df_total.Raw,
            Penalty = df_total.Penalty,
            Total = df_total.Total,
            Percent = df_total.Percent
        )

        if sym == :raw_vector
            return df.Raw
        elseif sym == :penalty_vector
            return df.Penalty
        elseif sym == :total_vector
            return df.Total
        elseif sym == :percent_vector
            return df.Percent
        end

        df.Letter = get_lettergrade(df)
        if sym == :letter_vector
            return df.Letter
        end

        df.GPA = get_gpa(df)
        if sym == :gpa_vector
            return df.GPA
        end

        df.Missing = get_missing(df, total_possible)
        if sym == :missing_vector
            return df.Missing
        end

        df.Absent = get_absent(gb, [students_idx...])
        if sym == :absent_vector
            return df.Absent
        end

        df.Extension = get_extension([students_idx...], gb.class.roster)
        if sym == :extension_vector
            return df.Extension
        end

        df.Accommodation = get_accommodation([students_idx...], gb.class.roster)
        if sym == :accommodation_vector
            return df.Accommodation
        end
    else
        error("Property $(sym) not found in Gradebook.")
    end
end

Base.propertynames(gb::Gradebook) = (:class, :grades, :raw, :penalty, :total, :raw_vector, :penalty_vector, :total_vector, :percent_vector, :letter_vector, :gpa_vector, :missing_vector, :absent_vector, :extension_vector, :accommodation_vector)

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
        submissions_df′′ = DataFrame(Matrix(submissions_df′)[findall(!ismissing, submissions_df′[!, by]), :], names(submissions_df′))
        submissions_df′′[!, 1] = convert.(String, submissions_df′′[!, 1])
        submissions_df′′[!, 2] = convert.(Point, (map(x->ismissing(x) ? 0.0 : (isa(x, AbstractString) ? parse(Float64, String(x)) : x), submissions_df′′[!, 2])))
        grades = Grade[]
        for row ∈ eachrow(submissions_df′′)
            push!(grades, grade(row[1], gb.class.roster, assignment, assignment.due, row[2]; threshold=threshold))
        end
        grades_post!(gb, grades)
    end
    return nothing
end

"Syncs current field value of `gb.grades` to gradebook."
grades_sync!(gb::Gradebook) = grades_post!(gb, gb.grades)
