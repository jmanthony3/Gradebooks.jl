export AbstractGradebook, Gradebook
export fill_grades!, fill_teams!, update_attendance!

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
        gb.raw_score[!, ["ID", "Preferred", "Last", "Team", "Email"]] .= vcat(map(x->[x.id x.name_preferred x.name_family 0 x.email], roster)...)
        gb.penalty[!, ["ID", "Preferred", "Last", "Team", "Email"]] .= vcat(map(x->[x.id x.name_preferred x.name_family 0 x.email], roster)...)
        gb.total[!, ["ID", "Preferred", "Last", "Team", "Email"]] .= vcat(map(x->[x.id x.name_preferred x.name_family 0 x.email], roster)...)
        # gb.total[!, Not(["ID", "Preferred", "Last", "Team", "Email"])] .= gb.raw_score[!, Not(["ID", "Preferred", "Last", "Team", "Email"])] - gb.penalty[!, Not(["ID", "Preferred", "Last", "Team", "Email"])]
    else
        gb.raw_score[!, ["ID", "Preferred", "Last", "Email"]] .= vcat(map(x->[x.id x.name_preferred x.name_family x.email], roster)...)
        gb.penalty[!, ["ID", "Preferred", "Last", "Email"]] .= vcat(map(x->[x.id x.name_preferred x.name_family x.email], roster)...)
        gb.total[!, ["ID", "Preferred", "Last", "Email"]] .= vcat(map(x->[x.id x.name_preferred x.name_family x.email], roster)...)
        # gb.total[!, Not(["ID", "Preferred", "Last", "Email"])] .= gb.raw_score[!, Not(["ID", "Preferred", "Last", "Email"])] - gb.penalty[!, Not(["ID", "Preferred", "Last", "Email"])]
    end
    return gb
end

function fill_grades!(gb::Gradebook{Class}, src, assignments::Vararg{Assignment})
    submissions_df = CSV.read(src, DataFrame)
    for assignment in collect(assignments)
        submissions_df′ = submissions_df[!, Cols("SIS Login ID", occursin.("$(string2codename(assignment.name))", map(x->"$x", string2codename.(names(submissions_df)))))]
        submissions_df′ = DataFrame(Matrix(submissions_df′)[findfirst(!ismissing, submissions_df′[!, "SIS Login ID"]):end-1, :], names(submissions_df′))
        submissions_df′[!, 1] = convert.(String, submissions_df′[!, 1])
        submissions_df′[!, 2] = convert.(Points, (map(x->ismissing(x) ? 0.0 : x, submissions_df′[!, 2])))

        submissions_dict = Dict{String, Submission}()
        for row in eachrow(submissions_df′)
            submissions_dict[row[1]] = Submission(assignment.due, Score(Points(row[2]), assignment.value))
        end

        grades = Dict(map(x->x[1]=>Grade(only(gb.who.roster[map(s->x[1]==string(split(s.email, "@")[1]), gb.who.roster)]), assignment, x[2]), collect(pairs(submissions_dict))))

        for (key, val) in grades
            gb.raw_score[occursin.(key, gb.raw_score[!, "Email"]), assignment.codename] .= val.submission.score.score
            t = val.submission.submitted - val.assignment.due
            p = if t < Millisecond(1)
                0.0
            else
                val.assignment.value * (t < Day(7) ? 0.1 : (t < Day(14) ? 0.2 : 1.0))
            end
            gb.penalty[occursin.(key, gb.penalty[!, "Email"]), assignment.codename] .= p
            gb.total[occursin.(key, gb.total[!, "Email"]), assignment.codename] .= gb.raw_score[occursin.(key, gb.raw_score[!, "Email"]), assignment.codename] - gb.penalty[occursin.(key, gb.penalty[!, "Email"]), assignment.codename]
        end
    end
    return nothing
end

function fill_grades!(gb::Gradebook{Class}, assignment::Assignment, grades::Vararg{Grade})
    for grade in collect(grades)
        gb.raw_score[occursin.(grade.student.email, gb.raw_score[!, "Email"]), assignment.codename] .= gradeval.submission.score.score
        t = grade.submission.submitted - grade.assignment.due
        p = if t < Millisecond(1)
            0.0
        else
            grade.assignment.value * (t < Day(7) ? 0.1 : (t < Day(14) ? 0.2 : 1.0))
        end
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
