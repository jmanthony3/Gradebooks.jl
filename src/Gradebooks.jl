module Gradebooks





export AbstractGradebookNode, LeafPath, #= assign_paths!, =# isleaf, rake_leaves
export update, withdraw!, reinstate!



using AbstractTrees
using Dates
import Printf: @sprintf



include("preferences.jl")
include("utils.jl")
include("datetime.jl")
include("credit.jl")
include("letter_grades.jl")


abstract type AbstractGradebookNode end

struct LeafPath
    parts::Tuple{Vararg{Symbol}}
end

# LeafPath(parts::Tuple{Vararg{Symbol}}=()) = LeafPath(tuple(parts...))
LeafPath(parts::Vector{Symbol}) = LeafPath(Tuple(parts))
LeafPath() = LeafPath(())


include("accommodations.jl")
include("assignments.jl")
include("people.jl")


# const _PATH_CACHE = Dict{UInt,LeafPath}()

# function clear_paths!()
#     empty!(_PATH_CACHE)
#     return nothing
# end

LeafPath(node::Nothing; prefix=())          = LeafPath(prefix)
LeafPath(node::LeafPath; prefix=())         = LeafPath(tuple(prefix..., node.parts...))
LeafPath(node::Symbol; prefix=())           = LeafPath(tuple(prefix..., node))
LeafPath(node::AbstractString; prefix=())   = LeafPath(tuple(prefix..., string2codename(node)))
LeafPath(node::Assignment; prefix=())       = LeafPath(tuple(prefix..., node.codename))
LeafPath(node::Question; prefix=())         = LeafPath(tuple(prefix..., node.codename))

# function leaf_path(node; prefix=())
#     if haskey(_PATH_CACHE, objectid(node))
#         return _PATH_CACHE[objectid(node)]
#     end

#     name = if hasproperty(node, :codename)
#         Symbol(node.codename)
#     elseif isa(node, AbstractGradebookNode)
#         Symbol(typeof(node).name.name)
#     else
#         nothing
#     end

#     path = isnothing(name) ? LeafPath(prefix) : LeafPath(tuple(prefix..., name))
#     _PATH_CACHE[objectid(node)] = path
#     return path
# end

# function assign_paths!(node::T, prefix=()) where {T <: AbstractGradebookNode}
#     current = leaf_path(node; prefix=prefix)
#     _PATH_CACHE[objectid(node)] = current
#     for child ∈ children(node)
#         assign_paths!(child, current.parts)
#     end
#     return nothing
# end

"Determines if a node is a leaf (i.e., has no children)."
isleaf(node::T) where {T <: AbstractGradebookNode} = isempty(children(node))

function rake_leaves(node::T; prefix=(), parent_value=nothing) where {T <: AbstractGradebookNode}
    trace = trace_leaf_resolution(node, parent_value; prefix=prefix)
    current_path = trace.path
    current_value = trace.resolved_value
    if isleaf(node)
        return [(current_path, node, parent_value, current_value)]
    else
        out = Tuple{LeafPath, Any, Any, Any}[]
        for child ∈ children(node)
            append!(out, rake_leaves(child; prefix=current_path.parts, parent_value=current_value))
        end
        return out
    end
end


include("class.jl")
include("grades.jl")
include("gradebook.jl")
include("attendance.jl")


function withdraw!(gb::Gradebook, student::Union{Student, String}; date::Date=today(), threshold=STRING_MATCH_THRESHOLD)
    if isa(student, String)
        student = get_student(student, gb.class.roster; threshold=threshold)
    end
    student.final_grade = LetterGrade("W")
    student.enrollment_status = Withdrawn
    student.withdrawal_date = date
    gb.class.roster.students[gb.class.roster.by_id[student.person.id]] = student
    return nothing
end

function reinstate!(gb::Gradebook, student::Union{Student, String}; date::Date=today(), threshold=STRING_MATCH_THRESHOLD)
    if isa(student, String)
        student = get_student(student, gb.class.roster; threshold=threshold)
    end
    student.notes[:withdrawal_date] = student.withdrawal_date  # preserve original withdrawal date
    student.notes[:reinstatement_date] = date  # or however you want to track reinstatement
    student.enrollment_status = Active
    student.withdrawal_date = nothing
    gb.class.roster.students[gb.class.roster.by_id[student.person.id]] = student
    return nothing
end


include("trees.jl")
include("base.jl")
include("plots.jl")
include("reports.jl")





end # end of module
