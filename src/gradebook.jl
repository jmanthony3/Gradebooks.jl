export AbstractGradebook, Gradebook
export fill_grades!, fill_teams!, update_attendance!, attendance!

using DataFrames

abstract type AbstractGradebook end # <: AbstractDataFrame end
struct Gradebook{T<:Union{Class,Student}} <: AbstractGradebook
    who::T
    raw_score::DataFrame
    penalty::DataFrame
    total::DataFrame
    assignments::Vector{Assignment}
    # Gradebook{T}(who, assignments, df) where {T<:Union{Class,Student}} = new{T}(who, assignments, df)
end
# Gradebook{Class}(class::Class, assignments::Vector{Assignment}) = new{Class}(class, assignments, DataFrame(zeros((length(class.roster), length(assignments))), [a.name for a in assignments]))
function Gradebook(who::T, assignments::Vector{Assignment}) where {T<:Union{Class,Student}}
    names = [string(a.codename) for a in assignments]
    if any(isa.(assignments, Assignment{<:AbstractAssignment, Group}))
        pushfirst!(names, "ID", "Preferred", "Last", "Team", "Email")
    else
        pushfirst!(names, "ID", "Preferred", "Last", "Email")
    end
    df = DataFrame(zeros(isa(who, Class) ? length(who.roster) : 1, length(names)), names)
    return Gradebook{T}(who, deepcopy(df), deepcopy(df), deepcopy(df), assignments)
end
function Gradebook(who::T, assignments::Vector{Assignment}, roster::Vector{Student}) where {T<:Union{Class,Student}}
    gb = Gradebook(who, assignments)
    if any(isa.(assignments, Assignment{<:AbstractAssignment, Group}))
        gb.raw_score[!, ["ID", "Preferred", "Last", "Team", "Email"]] .= vcat(map(x->[x.id (!isempty(x.name_preferred) ? x.name_preferred : x.name_given) x.name_family 0 x.email], roster)...)
        gb.penalty[!, ["ID", "Preferred", "Last", "Team", "Email"]] .= vcat(map(x->[x.id (!isempty(x.name_preferred) ? x.name_preferred : x.name_given) x.name_family 0 x.email], roster)...)
        gb.total[!, ["ID", "Preferred", "Last", "Team", "Email"]] .= vcat(map(x->[x.id (!isempty(x.name_preferred) ? x.name_preferred : x.name_given) x.name_family 0 x.email], roster)...)
        # gb.total[!, Not(["ID", "Preferred", "Last", "Team", "Email"])] .= gb.raw_score[!, Not(["ID", "Preferred", "Last", "Team", "Email"])] - gb.penalty[!, Not(["ID", "Preferred", "Last", "Team", "Email"])]
    else
        gb.raw_score[!, ["ID", "Preferred", "Last", "Email"]] .= vcat(map(x->[x.id (!isempty(x.name_preferred) ? x.name_preferred : x.name_given) x.name_family x.email], roster)...)
        gb.penalty[!, ["ID", "Preferred", "Last", "Email"]] .= vcat(map(x->[x.id (!isempty(x.name_preferred) ? x.name_preferred : x.name_given) x.name_family x.email], roster)...)
        gb.total[!, ["ID", "Preferred", "Last", "Email"]] .= vcat(map(x->[x.id (!isempty(x.name_preferred) ? x.name_preferred : x.name_given) x.name_family x.email], roster)...)
        # gb.total[!, Not(["ID", "Preferred", "Last", "Email"])] .= gb.raw_score[!, Not(["ID", "Preferred", "Last", "Email"])] - gb.penalty[!, Not(["ID", "Preferred", "Last", "Email"])]
    end
    return gb
end

function fill_grades!(gb::Gradebook{Class}, src, assignments::Vararg{Assignment})
    submissions_df = CSV.read(src, DataFrame)
    for assignment in collect(assignments)
        submissions_df′ = submissions_df[!, Cols("SIS Login ID", occursin.("$(string2codename(assignment.name))", map(x->"$x", string2codename.(names(submissions_df)))))]
        submissions_df′ = DataFrame(Matrix(submissions_df′)[findfirst(!ismissing, submissions_df′[!, "SIS Login ID"]):end, :], names(submissions_df′))
        submissions_df′[!, 1] = convert.(String, submissions_df′[!, 1])
        submissions_df′[!, 2] = convert.(Points, (map(x->ismissing(x) ? 0.0 : x, submissions_df′[!, 2])))

        submissions_dict = Dict{String, Submission}()
        for row in eachrow(submissions_df′)
            try
                get_student(gb.who.roster, row[1])
            catch
            else
                submissions_dict[row[1]] = Submission(assignment.due, Score(Points(row[2]), assignment.value), [Tally(try
                    only(assignment.questions)
                catch e
                    if isa(e, ArgumentError)
                        Question("{Completion}", assignment.value)
                    end
                end, Grant(Points(row[2])))])
            end
        end

        grades = Dict(map(x->x[1]=>Grade(get_student(gb.who.roster, x[1]), assignment, x[2]), collect(pairs(submissions_dict))))

        for (key, val) in grades
            gb.raw_score[occursin.(key, gb.raw_score[!, "Email"]), assignment.codename] .= val.submission.score.score
            t = val.submission.submitted - val.assignment.due
            p = Points(if t < Millisecond(1)
                0.0
            else
                val.assignment.value * (t < Day(7) ? 0.1 : (t < Day(14) ? 0.2 : 1.0))
            end)
            gb.penalty[occursin.(key, gb.penalty[!, "Email"]), assignment.codename] .= p
            gb.total[occursin.(key, gb.total[!, "Email"]), assignment.codename] .= gb.raw_score[occursin.(key, gb.raw_score[!, "Email"]), assignment.codename] - gb.penalty[occursin.(key, gb.penalty[!, "Email"]), assignment.codename]
        end
    end
    return nothing
end

function fill_grades!(gb::Gradebook{Class}, assignment::Assignment, grades::Vararg{Grade})
    for grade in collect(grades)
        gb.raw_score[occursin.(grade.student.email, gb.raw_score[!, "Email"]), assignment.codename] .= grade.submission.score.score
        t = grade.submission.submitted - grade.assignment.due
        p = Points(if t < Millisecond(1)
            0.0
        else
            grade.assignment.value * (t < Day(7) ? 0.1 : (t < Day(14) ? 0.2 : 1.0))
        end)
        gb.penalty[occursin.(grade.student.email, gb.penalty[!, "Email"]), assignment.codename] .= p
        gb.total[occursin.(grade.student.email, gb.total[!, "Email"]), assignment.codename] .= gb.raw_score[occursin.(grade.student.email, gb.raw_score[!, "Email"]), assignment.codename] - gb.penalty[occursin.(grade.student.email, gb.penalty[!, "Email"]), assignment.codename]
    end
    return nothing
end

function fill_teams!(gb::Gradebook{Class}, teams::Vararg{Team})
    for df in [gb.raw_score, gb.penalty, gb.total]
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

function attendance!(att::Gradebook, roster, lectures::Vector{Assignment}, dir)
    lecture_dates = map(y->Date(y.due), lectures)
    for course_export in readdir(dir; join=true)
        if occursin(r"export-\d+\+att(endance)?\.csv", basename(course_export))
            # @show basename(course_export)
            submissions_df = CSV.read(course_export, DataFrame)
            submissions_df = submissions_df[!, Cols("Email", 8:2:end-1)]
            dates = map(x->x[1:findfirst('T', x)-1], collect(submissions_df[1, :])[2:end][findall(x->(length(x)==25 && occursin('T', x)), collect(submissions_df[1, :])[2:end])])
            submissions_df = DataFrame(Matrix(submissions_df)[findfirst(!ismissing, submissions_df[!, "Email"]):end, begin:end-(length(collect(submissions_df[1, :])[2:end]) - length(dates))], ["Email", dates...])
            submissions_df[!, 1] = convert.(String, submissions_df[!, 1])
            for i in 2:1:length(names(submissions_df))
                submissions_df[!, i] = convert.(String, submissions_df[!, i])
                submissions_df[!, i] = convert.(Points, (map(x->ismissing(x) ? 0.0 : (x == "--" ? Inf : parse(Float64, x)), submissions_df[!, i])))
            end
            # submissions_df[!, 2] = convert.(Points, (map(x->ismissing(x) ? 0.0 : x, submissions_df[!, 2])))
            select!(submissions_df, ["Email", sort(names(submissions_df)[2:end])...])

            for (i, ld) in enumerate(names(submissions_df)[2:end])
                cl_idx = findfirst(Date(ld) .== lecture_dates)
                cl = "CL$cl_idx"
                if isnothing(cl_idx)
                    @show (i, ld)
                # elseif cl ∈ names(att.total)
                #     @show (i, ld)
                elseif cl ∉ names(att.total)
                    lecture = lectures[cl_idx]
                    local submissions_dict = Dict{String, Submission}()
                    for row in eachrow(select(submissions_df, ["Email", ld]))
                        submissions_dict[row[1]] = Submission(lecture.due, Score(Points(row[2]), lecture.value), [Tally(only(lecture.questions), Grant(Points(row[2])))])
                    end

                    submissions_dict_emails = map(x->string(split(x[1], "@")[1]), collect(pairs(submissions_dict)))
                    # @show submissions_dict_emails
                    roster_emails = map(x->string(split(x.email, "@")[1]), roster)
                    # @show roster_emails
                    emails_possible = intersect(submissions_dict_emails, roster_emails)
                    # @show emails_possible
                    emails_possible_roster_idx = findall(x->x ∈ emails_possible, roster_emails)
                    # @show emails_possible_roster_idx
                    emails_possible_submissions_idx = findall(x->x ∈ emails_possible, submissions_dict_emails)
                    # @show emails_possible_submissions_idx
                    grades = Dict(map(x->x[1]=>Grade(only(roster[findall(s->s==string(split(x[1], "@")[1]), roster_emails[emails_possible_roster_idx])]), lecture, x[2]), collect(pairs(submissions_dict))[emails_possible_submissions_idx]))

                    try
                        insertcols!(att.raw_score, 4 + cl_idx, lecture.codename => fill(Points(Inf), nrow(att.raw_score)))
                        insertcols!(att.penalty, 4 + cl_idx, lecture.codename => zeros(Points, nrow(att.penalty)))
                        insertcols!(att.total, 4 + cl_idx, lecture.codename => zeros(Points, nrow(att.total)))
                    catch
                        j = (ncol(att.raw_score) - 4) + 1
                        while j < cl_idx
                            # @show j
                            insertcols!(att.raw_score, 4 + j, lectures[j].codename => fill(Points(Inf), nrow(att.raw_score)))
                            insertcols!(att.penalty, 4 + j, lectures[j].codename => zeros(Points, nrow(att.penalty)))
                            insertcols!(att.total, 4 + j, lectures[j].codename => zeros(Points, nrow(att.total)))
                            j += 1
                        end
                        insertcols!(att.raw_score, 4 + cl_idx, lecture.codename => fill(Points(Inf), nrow(att.raw_score)))
                        insertcols!(att.penalty, 4 + cl_idx, lecture.codename => zeros(Points, nrow(att.penalty)))
                        insertcols!(att.total, 4 + cl_idx, lecture.codename => zeros(Points, nrow(att.total)))
                    end
                    for (key, val) in grades
                        att.raw_score[occursin.(key, att.raw_score[!, "Email"]), lecture.codename] .= val.submission.score.score
                        t = count(==(-1), Matrix(att.raw_score[occursin.(key, att.raw_score[!, "Email"]), :])) + count(==(0), Matrix(att.raw_score[occursin.(key, att.raw_score[!, "Email"]), :]))
                        p = if t <= 4
                            0.0
                        else
                            (t - 4) * Points(50)
                        end
                        att.penalty[occursin.(key, att.penalty[!, "Email"]), lecture.codename] .= p
                        att.total[occursin.(key, att.total[!, "Email"]), lecture.codename] .= att.raw_score[occursin.(key, att.raw_score[!, "Email"]), lecture.codename] - att.penalty[occursin.(key, att.penalty[!, "Email"]), lecture.codename]
                    end
                end
            end
        end
    end
    return nothing
end

function attendance!(att::Gradebook, roster, lectures::Vector{Assignment}, date::Date, student_mark_pairs::Vararg{Tuple{String, AbstractMark}})
    lecture = lectures[findfirst(x->x==date, map(y->Date(y.due), lectures))]
    try
        insertcols!(att.raw_score, ncol(att.raw_score) + 1, lecture.codename=>zeros(Points, nrow(att.raw_score)))
        insertcols!(att.penalty, ncol(att.penalty) + 1, lecture.codename=>zeros(Points, nrow(att.penalty)))
        insertcols!(att.total, ncol(att.total) + 1, lecture.codename=>zeros(Points, nrow(att.total)))
    catch
    end
    submissions_dict = Dict{String, Submission}()
    for (student, mark) in student_mark_pairs
        submissions_dict[student] = Submission(lecture.due, Score(lecture, [mark]), [Tally(only(lecture.questions), mark)])
    end

    grades = Dict(map(x->get_student(roster, x[1]).email=>Grade(get_student(roster, x[1]), lecture, x[2]), collect(pairs(submissions_dict))))
    for (key, val) in grades
        att.raw_score[occursin.(key, att.raw_score[!, "Email"]), lecture.codename] .= val.submission.score.score
        t = count(==(-1), Matrix(att.raw_score[occursin.(key, att.raw_score[!, "Email"]), :])) + count(==(0), Matrix(att.raw_score[occursin.(key, att.raw_score[!, "Email"]), :]))
        p = if t <= 4
            0.0
        else
            (t - 4) * Points(50)
        end
        att.penalty[occursin.(key, att.penalty[!, "Email"]), lecture.codename] .= p
        att.total[occursin.(key, att.total[!, "Email"]), lecture.codename] .= att.penalty[occursin.(key, att.penalty[!, "Email"]), lecture.codename]
    end
    return nothing
end

function update_attendance!(att::Gradebook{Class}, lectures)
    for (i, row) in enumerate(eachrow(att.raw_score))
        for j in 5:1:ncol(att.raw_score)
            t = count(==(-1), collect(row)[5:j]) + count(==(0), collect(row)[5:j])
            p = if t <= 4
                0.0
            else
                (t - 4) * Points(50)
            end
            # @show i, j, p
            att.penalty[occursin.(row["Email"], att.raw_score[!, "Email"]), lectures[j - 4].codename] .= p
            att.total[occursin.(row["Email"], att.raw_score[!, "Email"]), lectures[j - 4].codename] .= att.penalty[i, j]
        end
    end
    return nothing
end
