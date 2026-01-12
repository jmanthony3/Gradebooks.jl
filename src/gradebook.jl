# export AbstractGradebook, Gradebook, StudentGradebook, ClassGradebook

# using DataFrames

# abstract type AbstractGradebook <: AbstractDataFrame end
# struct Gradebook{T<:Union{Class,Student}} <: AbstractGradebook
#     who::T
#     data::DataFrame
#     assignments::Vector{Assignment}
#     # Gradebook{T}(who, assignments, df) where {T<:Union{Class,Student}} = new{T}(who, assignments, df)
# end
# # Gradebook{Class}(class::Class, assignments::Vector{Assignment}) = new{Class}(class, assignments, DataFrame(zeros((length(class.roster), length(assignments))), [a.name for a in assignments]))
# function Gradebook(who::T, assignments::Vector{Assignment}) where {T<:Union{Class,Student}}
#     names = [string(a.codename) for a in assignments]
#     if any(isa.(assignments, AbstractAssignment{Group}))
#         pushfirst!(names, ["ID", "Preferred", "Last", "Team", "Email"])
#     else
#         pushfirst!(names, ["ID", "Preferred", "Last", "Email"])
#     end
#     return Gradebook{T}(who, DataFrame(zeros(isa(who, Class) ? length(who.roster) : 1, length(names)), names), assignments)
# end

# const StudentGradebook = Gradebook{Student}
# const ClassGradebook = Gradebook{Class}
# # const Attendance{T} = Gradebook{T}
# # const StudentAttendance = Attendance{Student}
# # const ClassAttendance = Attendance{Class}


export Gradebook

# https://tables.juliadata.org/stable/implementing-the-interface/#Implementation-Example
using Tables

struct Gradebook{T <: AbstractVecOrMat} <: Tables.AbstractColumns
    names::Vector{Symbol}
    lookup::Dict{Symbol, Int}
    students::Vector{Student}
    matrix::T
end
# declare that MatrixTable is a table
Tables.istable(::Type{<:Gradebook}) = true
# getter methods to avoid getproperty clash
names(m::Gradebook) = getfield(m, :names)
lookup(m::Gradebook) = getfield(m, :lookup)
students(m::Gradebook) = getfield(m, :students)
matrix(m::Gradebook) = getfield(m, :matrix)
# schema is column names and types
Tables.schema(m::Gradebook{T}) where {T} = Tables.Schema(names(m), fill(eltype(T), size(matrix(m), 2)))

# column interface
Tables.columnaccess(::Type{<:Gradebook}) = true
Tables.columns(m::Gradebook) = m
# required Tables.AbstractColumns object methods
Tables.getcolumn(m::Gradebook, ::Type{T}, col::Int, nm::Symbol) where {T} = matrix(m)[:, col]
Tables.getcolumn(m::Gradebook, nm::Symbol) = matrix(m)[:, lookup(m)[nm]]
Tables.getcolumn(m::Gradebook, i::Int) = matrix(m)[:, i]
Tables.columnnames(m::Gradebook) = names(m)

# declare that any MatrixTable defines its own `Tables.rows` method
rowaccess(::Type{<:Gradebook}) = true
# just return itself, which means MatrixTable must iterate `Tables.AbstractRow`-compatible objects
rows(m::Gradebook) = m
# the iteration interface, at a minimum, requires `eltype`, `length`, and `iterate`
# for `MatrixTable` `eltype`, we're going to provide a custom row type
Base.eltype(m::Gradebook{T}) where {T} = GradebookRow{T}
Base.length(m::Gradebook) = size(matrix(m), 1)

Base.iterate(m::Gradebook, st=1) = st > length(m) ? nothing : (GradebookRow(st, m), st + 1)

# a custom row type; acts as a "view" into a row of an AbstractVecOrMat
struct GradebookRow{T} <: Tables.AbstractRow
    row::Int
    source::Gradebook{T}
end
# required `Tables.AbstractRow` interface methods (same as for `Tables.AbstractColumns` object before)
# but this time, on our custom row type
getcolumn(m::GradebookRow, ::Type, col::Int, nm::Symbol) =
    getfield(getfield(m, :source), :matrix)[getfield(m, :row), col]
getcolumn(m::GradebookRow, i::Int) =
    getfield(getfield(m, :source), :matrix)[getfield(m, :row), i]
getcolumn(m::GradebookRow, nm::Symbol) =
    getfield(getfield(m, :source), :matrix)[getfield(m, :row), getfield(getfield(m, :source), :lookup)[nm]]
columnnames(m::GradebookRow) = names(getfield(m, :source))

const StudentGradebook = GradebookRow

function post_grades!(gb::Gradebook, grades::Grade...)
    for grade in grades
        i = findfirst(x->x==grade.student.email, gb.students)
        if isnothing(i)
            @error "Student not found in roster by email" grade.student.email
        end
        gb_row = GradebookRow(i, gb)
        j = findfirst(x->x==grade.assignment.codename, gb.names)
        if isnothing(j)
            @error "Assignment not found by code name" grade.assignment.codename
        end
        gb_row[j] = grade.submission
    end
    return gb
end
