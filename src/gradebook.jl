export AbstractGradebook, Gradebook
# export StudentGradebook, ClassGradebook

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
        gb.raw_score[!, ["ID", "Preferred", "Last", "Email"]] .= vcat(map(x->[x.id x.name_preferred x.name_family x.email], eachrow(roster))...)
        gb.penalty[!, ["ID", "Preferred", "Last", "Email"]] .= vcat(map(x->[x.id x.name_preferred x.name_family x.email], eachrow(roster))...)
        gb.total[!, ["ID", "Preferred", "Last", "Email"]] .= vcat(map(x->[x.id x.name_preferred x.name_family x.email], eachrow(roster))...)
        # gb.total[!, Not(["ID", "Preferred", "Last", "Email"])] .= gb.raw_score[!, Not(["ID", "Preferred", "Last", "Email"])] - gb.penalty[!, Not(["ID", "Preferred", "Last", "Email"])]
    end
    return gb
end

# const StudentGradebook = Gradebook{Student}
# const ClassGradebook = Gradebook{Class}
# const Attendance{T} = Gradebook{T}
# const StudentAttendance = Attendance{Student}
# const ClassAttendance = Attendance{Class}
