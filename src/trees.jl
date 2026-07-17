using AbstractTrees



AbstractTrees.children(node::Person) = () # leaf
AbstractTrees.children(node::Instructor) = node.person
AbstractTrees.children(node::Student) = node.person
AbstractTrees.children(node::Roster) = node.students
AbstractTrees.children(node::Team) = node.roster.students
AbstractTrees.children(node::Question) = hasproperty(node, :parts) && !isnothing(node.parts) && !isempty(node.parts) ? node.parts : () # leaf
AbstractTrees.children(node::Rubric) = node.metrics
AbstractTrees.children(node::Assignment) = node.questions
AbstractTrees.children(node::Course) = node.assignments
AbstractTrees.children(node::Class) = vcat(course, node.lectures, node.instructors, node.roster.students)
AbstractTrees.children(node::Evaluation) = () # leaf
AbstractTrees.children(node::Score) = () # leaf
AbstractTrees.children(node::Submission) = node.evaluations
AbstractTrees.children(node::Grade) = node.submission
AbstractTrees.children(node::Gradebook) = vcat(node.class.course.assignments, node.class.lectures, node.class.roster.students)


function wrap_with_ids(node::Question, path::Vector{Symbol} = Symbol[])
    new_path = vcat(path, node.codename)
    wrapped_parts = hasproperty(node, :parts) && !isnothing(node.parts) && !isempty(node.parts) ? map(node.parts) do p
        wrap_with_ids(p, new_path)
    end : ()
    return GradebookNode(Question(node.name, node.codename, node.value, wrapped_parts), LeafPath(new_path))
end

function wrap_with_ids(node::Assignment, path::Vector{Symbol} = Symbol[])
    new_path = vcat(path, node.codename)
    wrapped_questions = map(node.questions) do q
        wrap_with_ids(q, new_path)
    end
    return GradebookNode(Assignment(node.name, node.codename, node.value, node.category, wrapped_questions), LeafPath(new_path))
end

function find_node(tree::Gradebook, target_id::LeafPath)
    for assignment in tree.class.course.assignments
        for node in AbstractTrees.PreOrderDFS(assignment)
            if node.id == target_id
                return node
            end
        end
    end
    error("Node not found: $target_id")
end

find_node(tree::Vector{Assignment}, codename_path::Vector{Symbol}) = find_node(tree, LeafPath(codename_path))


# AbstractTrees.printnode(io::IO, node::AbstractGradebookNode) = print(io, node.name)
AbstractTrees.printnode(io::IO, node::Person) = print(io, node.name)
AbstractTrees.printnode(io::IO, node::Instructor) = print(io, join([repr(node.person), node.job_title], " "))
AbstractTrees.printnode(io::IO, node::Student) = print(io, join([repr(node.person), node.discipline #=, string(node.enrollment_status), (!isnothing(node.final_grade) ? repr(node.final_grade) : "n/a"), string(node.withdrawal_date), node.notes=#], " "))
AbstractTrees.printnode(io::IO, node::Roster) = print(io, join(map(s->AbstractTrees.printnode(io, s), node.students), "\n"))
AbstractTrees.printnode(io::IO, node::Team) = print(io, node.name * " (" * string(node.codename) * "):" * string(first(node.roster.students)))
AbstractTrees.printnode(io::IO, node::Question) = print(io, node.name * " (" * string(node.codename) * "): " * string(round(node.value.value; digits=COURSE_POINT_DECIMALPLACES)), "\n", isnothing(node.parts) ? nothing : join(map(p->AbstractTrees.printnode(io, p), node.parts), "\n\t"))
AbstractTrees.printnode(io::IO, node::Evaluation) = print(io, join([AbstractTrees.printnode(io, node.target), node.mark, node.comment], "\n"))
AbstractTrees.printnode(io::IO, node::Rubric) = print(io, node.name * " (" * string(node.codename) * "): " * string(round(node.value.value; digits=COURSE_POINT_DECIMALPLACES)), "\n", join(map(m->AbstractTrees.printnode(io, m), node.metrics), "\n\t"))
AbstractTrees.printnode(io::IO, node::Assignment) = print(io, string(node.codename) * " (" * repr(node.value) * ") " * "[" * string(node.due) * "] \n" * join(map(q->AbstractTrees.printnode(io, q), node.questions), "\n\t"))
AbstractTrees.printnode(io::IO, node::Course) = print(io, string(node.code) * string(node.number) * ": " * node.name, " (" * string(node.credits) * ")")
# AbstractTrees.printnode(io::IO, node::Term) = print(io, string(node.code) * ": " * node.name * " (" * string(node.start) * " - " * string(node.finish) * ")")
AbstractTrees.printnode(io::IO, node::Class) = print(io, string(node.codename_long))
AbstractTrees.printnode(io::IO, node::Score) = print(io, string(node.earned) * " / " * string(node.value) * " (" * repr(node.percent) * ", " * repr(node.letter) *  ")" * (isempty(node.comment) ? "" : "# ") * node.comment)
AbstractTrees.printnode(io::IO, node::Submission) = print(io, "[" * string(node.submitted) * "] " * AbstractTrees.printnode(io, node.score), "\n", join(map(e->AbstractTrees.printnode(io, e), node.evaluations), "\n\t"))
AbstractTrees.printnode(io::IO, node::Grade) = print(io, node.student.person.name * " " * string(node.assignment.codename) * " " * AbstractTrees.printnode(io, node.submission))


AbstractTrees.NodeType(::Type{<:AbstractGradebookNode}) = AbstractTrees.HasNodeType()
