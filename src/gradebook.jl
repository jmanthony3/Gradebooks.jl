export AbstractGradebook, Gradebook, StudentGradebook, ClassGradebook

using DataFrames

abstract type AbstractGradebook <: AbstractDataFrame end
struct Gradebook{T<:Union{Class,Student}} <: AbstractGradebook
    data::DataFrame
    assignments::Vector{Assignment}
    who::T
    # Gradebook{T}(who, assignments, df) where {T<:Union{Class,Student}} = new{T}(who, assignments, df)
end
# Gradebook{Class}(class::Class, assignments::Vector{Assignment}) = new{Class}(class, assignments, DataFrame(zeros((length(class.roster), length(assignments))), [a.name for a in assignments]))
function Gradebook{Class}(class::Class, assignments)
    names = [a.name for a in assignments]
    if any(isa.(assignments, AbstractAssignment{Group}))
        pushfirst!(names, ["ID", "Preferred", "Last", "Team", "Email"])
    else
        pushfirst!(names, ["ID", "Preferred", "Last", "Email"])
    end
    Gradebook{Class}(class, DataFrame(zeros((length(class.roster), length(names))), names))
end
Gradebook{Student}(student::Student, assignments) = Gradebook{Student}(student, DataFrame(zeros((1, length(assignments))), [a.name for a in assignments]))
const StudentGradebook = Gradebook{Student}
const ClassGradebook = Gradebook{Class}
# const Attendance{T} = Gradebook{T}
# const StudentAttendance = Attendance{Student}
# const ClassAttendance = Attendance{Class}
