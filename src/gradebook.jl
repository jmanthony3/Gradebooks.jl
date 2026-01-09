export AbstractGradebook, Gradebook, StudentGradebook, ClassGradebook

using DataFrames

abstract type AbstractGradebook <: AbstractDataFrame end
struct Gradebook{T<:Union{Class,Student}} <: AbstractGradebook
    who::T
    data::DataFrame
    assignments::Vector{Assignment}
    # Gradebook{T}(who, assignments, df) where {T<:Union{Class,Student}} = new{T}(who, assignments, df)
end
# Gradebook{Class}(class::Class, assignments::Vector{Assignment}) = new{Class}(class, assignments, DataFrame(zeros((length(class.roster), length(assignments))), [a.name for a in assignments]))
function Gradebook(who::T, assignments::Vector{Assignment}) where {T<:Union{Class,Student}}
    names = [string(a.codename) for a in assignments]
    if any(isa.(assignments, AbstractAssignment{Group}))
        pushfirst!(names, ["ID", "Preferred", "Last", "Team", "Email"])
    else
        pushfirst!(names, ["ID", "Preferred", "Last", "Email"])
    end
    return Gradebook{T}(who, DataFrame(zeros(isa(who, Class) ? length(who.roster) : 1, length(names)), names), assignments)
end

const StudentGradebook = Gradebook{Student}
const ClassGradebook = Gradebook{Class}
# const Attendance{T} = Gradebook{T}
# const StudentAttendance = Attendance{Student}
# const ClassAttendance = Attendance{Class}
