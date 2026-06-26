import Base: +, -, *, /, ==, <, <=, >, >=, zero, one, float, convert, promote_rule, show, parse



# const Dictable = Union{Credit,LetterGrade,Person,Assignment,Course}
# const Indictable = Union{Class,Submission,Grade}

# convert(::Type{Dict}, x::Dictable) = (fns = fieldnames(x); Dict(zip(fns, getfield.(x, fns))))
# convert(::Type{DataFrame}, x::Dictable) = DataFrame(Dict(x))


# function +(a::DataFrame, b::DataFrame)
#     if allequal(names, [a, b])
#         c = deepcopy(a)
#         for name in names(a)
#             c[!, name] .= a[!, name] + b[!, name]
#         end
#         return c
#     else
#         names_itx = intersect(names(a), names(b))
#         @error "Not all names of `a` occur in `b`" a=names(a)[findall(n->n ∉ names_itx, names(a))] b=names(b)[findall(n->n ∉ names_itx, names(b))]
#         error("Cannot perform operation")
#     end
# end

# function -(a::DataFrame, b::DataFrame)
#     if allequal(names, [a, b])
#         c = deepcopy(a)
#         for name in names(a)
#             c[!, name] .= a[!, name] - b[!, name]
#         end
#         return c
#     else
#         names_itx = intersect(names(a), names(b))
#         @error "Not all names of `a` occur in `b`" a=names(a)[findall(n->n ∉ names_itx, names(a))] b=names(b)[findall(n->n ∉ names_itx, names(b))]
#         error("Cannot perform operation")
#     end
# end

# function *(a::DataFrame, b::DataFrame)
#     if allequal(names, [a, b])
#         c = deepcopy(a)
#         for name in names(a)
#             c[!, name] .= a[!, name] * b[!, name]
#         end
#         return c
#     else
#         names_itx = intersect(names(a), names(b))
#         @error "Not all names of `a` occur in `b`" a=names(a)[findall(n->n ∉ names_itx, names(a))] b=names(b)[findall(n->n ∉ names_itx, names(b))]
#         error("Cannot perform operation")
#     end
# end

# function /(a::DataFrame, b::DataFrame)
#     if allequal(names, [a, b])
#         c = deepcopy(a)
#         for name in names(a)
#             c[!, name] .= a[!, name] / b[!, name]
#         end
#         return c
#     else
#         names_itx = intersect(names(a), names(b))
#         @error "Not all names of `a` occur in `b`" a=names(a)[findall(n->n ∉ names_itx, names(a))] b=names(b)[findall(n->n ∉ names_itx, names(b))]
#         error("Cannot perform operation")
#     end
# end



## Gradebooks.jl
    show(io::IO, x::Course) = print(io, join(["              Code: " * x.code, "            Number: " * x.number, "              Name: " * x.name, "           Credits: " * x.credits, "  # of Assignments: " * x.assignments, "          Codename: " * x.codename], "\n"))
    show(io::IO, x::Term) = print(io, join(["             Name: " * x.name, "     Calendar Type: " * x.calendar_type, "              Year: " * x.year, "        Start Date: " * x.date, "       Finish Date: " * x.date, "              Code: " * x.code, "\t          Metadata: " * x.metadata], "\n"))
    show(io::IO, x::Class) = print(io, join([show(io, x.course), show(io, x.term), "           Section: " * x.section, "         Frequency: " * x.frequency, "        Start Time: " * x.time_start, "       Finish Time: " * x.time_finish, "     Duration Time: " * x.time_duration, "Number of Lectures: " * length(x.lectures), "  Codename (Short): " * x.codename_short, "   Codename (Long): " * x.codename_long, "Primary Instructor: " * x.primary_instructor, "       Instructors: " * x.instructors, "            Roster: " * x.roster], "\n"))



## credit.jl
    *(x::Real, ::Type{Point}) = Point(Float64(x))

    +(a::Point, b::Point) = Point(a.val + b.val)
    -(a::Point, b::Point) = Point(a.val - b.val)
    # *(a::Point, b::Point) = Point(a.x * b.x)
    /(a::Point, b::Point) = Percent(a.val / b.val)
    ==(a::Point, b::Point) = a.val == b.val
    <(a::Point, b::Point) = a.val < b.val
    <=(a::Point, b::Point) = a.val <= b.val
    >(a::Point, b::Point) = a.val > b.val
    >=(a::Point, b::Point) = a.val >= b.val
    zero(::Type{Point}) = Point(0.0)
    one(::Type{Point}) = Point(1.0)
    show(io::IO, x::Point) = print(io, round(x.val; digits=COURSE_POINT_DECIMALPLACES))
    float(x::Point) = x.val
    convert(::Type{Float64}, x::Point) = x.val
    promote_rule(::Type{Point}, ::Type{Float64}) = Float64
    promote_rule(::Type{Point}, ::Type{T}) where {T<:Real} = promote_rule(Float64, T)
    parse(::Type{Point}, s::AbstractString) = Point(parse(Float64, s))


    *(x::Real, ::Type{Percent}) = Percent(Float64(x))

    +(a::Percent, b::Percent) = Percent(a.val + b.val)
    -(a::Percent, b::Percent) = Percent(a.val - b.val)
    *(a::Percent, b::Percent) = Percent(a.val * b.val)
    /(a::Percent, b::Percent) = Percent(a.val / b.val)
    ==(a::Percent, b::Percent) = a.val == b.val
    <(a::Percent, b::Percent) = a.val < b.val
    <=(a::Percent, b::Percent) = a.val <= b.val
    >(a::Percent, b::Percent) = a.val > b.val
    >=(a::Percent, b::Percent) = a.val >= b.val
    zero(::Type{Percent}) = Percent(0.0)
    one(::Type{Percent}) = Percent(1.0)
    show(io::IO, x::Percent) = print(io, round(x.val; digits=COURSE_POINT_DECIMALPLACES), " %")
    float(x::Percent) = x.val
    convert(::Type{Float64}, x::Percent) = x.val
    # convert(::Type{Char}, x::Percent) = (x >= 0.90 ? 'A' : (x >= 0.80 ? 'B' : (x >= 0.70 ? 'C' : (x >= 0.60 ? 'D' : 'F'))))
    promote_rule(::Type{Percent}, ::Type{Float64}) = Float64
    promote_rule(::Type{Percent}, ::Type{T}) where {T<:Real} = promote_rule(Float64, T)
    parse(::Type{Percent}, s::AbstractString) = Percent(100parse(Float64, s))


    *(a::Point, b::Percent) = Point(a.val * b.val)
    *(a::Percent, b::Point) = Point(a.val * b.val)


    +(a::Mark, b::Mark) = Mark(a.delta + b.delta; comment=join([a.comment, b.comment], "\n")) # , a.value + b.value)
    -(a::Mark, b::Mark) = Mark(a.delta - b.delta; comment=join([a.comment, b.comment], "\n")) # , a.value - b.value)
    # *(a::Mark, b::Mark) = Mark(a.delta * b.delta; comment=join([a.comment, b.comment], "\n")) # , a.value * b.value)
    # /(a::Mark, b::Mark) = Mark(a.delta / b.delta; comment=join([a.comment, b.comment], "\n")) # , a.value / b.value)
    ==(a::Mark, b::Mark) = a.delta == b.delta
    <(a::Mark, b::Mark) = a.delta < b.delta
    <=(a::Mark, b::Mark) = a.delta <= b.delta
    >(a::Mark, b::Mark) = a.delta > b.delta
    >=(a::Mark, b::Mark) = a.delta >= b.delta
    show(io::IO, x::Mark) = print(io, x.delta, " # ", x.comment)
    float(x::Mark) = x.delta.val
    convert(::Type{Float64}, x::Mark) = x.delta.val
    promote_rule(::Type{Mark}, ::Type{Float64}) = Float64
    promote_rule(::Type{Mark}, ::Type{T}) where {T<:Real} = promote_rule(Float64, T)


    +(a::Mark, b::Real) = Mark(a.delta + Float64(b), a.comment)
    +(a::Real, b::Mark) = Mark(Float64(a) + b.delta, b.comment)
    -(a::Mark, b::Real) = Mark(a.delta - Float64(b), a.comment)
    *(a::Mark, b::Real) = Mark(a.delta * Float64(b), a.comment)
    *(a::Real, b::Mark) = Mark(Float64(a) * b.delta, b.comment)
    /(a::Mark, b::Real) = Mark(a.delta / Float64(b), a.comment)

    +(a::Mark, b::Percent) = Mark(a.delta + b, a.comment)
    +(a::Percent, b::Mark) = Mark(a + b.delta, b.comment)
    -(a::Mark, b::Percent) = Mark(a.delta - b, a.comment)
    *(a::Mark, b::Percent) = Mark(a.delta * b, a.comment)
    *(a::Percent, b::Mark) = Mark(a * b.delta, b.comment)
    /(a::Mark, b::Percent) = Mark(a.delta / b, a.comment)



## letter_grades.jl
    show(io::IO, g::GradeLevel) = print(io, determine_level(g))
    float(x::GradeLevel) = Float64(quality_points(x))
    convert(::Type{Float64}, x::GradeLevel) = Float64(quality_points(x))
    promote_rule(::Type{GradeLevel}, ::Type{Float64}) = Float64
    promote_rule(::Type{GradeLevel}, ::Type{T}) where {T<:Real} = promote_rule(Float64, T)


    ==(a::LetterGrade, b::LetterGrade) = quality_points(a) == quality_points(b)
    <(a::LetterGrade, b::LetterGrade) = quality_points(a) < quality_points(b)
    <=(a::LetterGrade, b::LetterGrade) = quality_points(a) <= quality_points(b)
    >(a::LetterGrade, b::LetterGrade) = quality_points(a) > quality_points(b)
    >=(a::LetterGrade, b::LetterGrade) = quality_points(a) >= quality_points(b)
    show(io::IO, x::LetterGrade) = print(io, x.string)
    float(x::LetterGrade) = x.quality_points
    convert(::Type{Float64}, x::LetterGrade) = x.quality_points
    promote_rule(::Type{LetterGrade}, ::Type{Float64}) = Float64
    promote_rule(::Type{LetterGrade}, ::Type{T}) where {T<:Real} = promote_rule(Float64, T)
    Base.string(x::LetterGrade) = x.string
    convert(::Type{String}, x::LetterGrade) = x.string
    convert(::Type{LetterGrade}, x::AbstractString) = LetterGrade(x)

    *(a::LetterGrade, b::Real) = gpa(a, b)
    *(a::Real, b::LetterGrade) = gpa(b, a)



## people.jl
    show(io::IO, x::Person) = print(io, join(["              Name: " * x.name, "           Aliases: " * x.aliases, "             Email: " * x.email, "             Phone: " * x.phone, "      Organization: " * x.organization, "                ID: " * x.id, "              Code: ", x.codename], "\n"))
    show(io::IO, x::Instructor) = print(io, join([x.person, "         Job Title: " * x.job_title], "\n"))
    show(io::IO, x::Student) = print(io, join([x.person, "        Discipline: " * x.discipline, "        Enrollment: " * x.enrollment_status, "       Final Grade: " * x.final_grade, "   Withdrawal Date: " * x.withdrawal_date, "             Notes: ", x.notes], "\n"))
    show(io::IO, x::Roster) = print(io, join(map(s->join(["              Name: " * x.name, "\t           Aliases: " * x.aliases, "\t             Email: " * x.email, "\t             Phone: " * x.phone, "\t      Organization: " * x.organization, "\t                ID: " * x.id, "\t              Code: ", x.codename, "\t        Discipline: " * x.discipline, "\t        Enrollment: " * x.enrollment_status, "\t       Final Grade: " * x.final_grade, "\t   Withdrawal Date: " * x.withdrawal_date, "\t             Notes: ", x.notes], "\n"), x.students), "\n"))
    show(io::IO, x::Team) = print(io, x.name, " (", x.codename, "):", first(x.roster.students))



## assignments.jl
    # +(a::Question, b::Question) = a.value + b.value # Question(join([a.name, b.name], "\n"), a.value + b.value, join(filter(x->!isnothing(x), [a.parts, b.parts]), "\n"))
    # -(a::Question, b::Question) = a.value - b.value # Question(join([a.name, b.name], "\n"), a.value - b.value, join(filter(x->!isnothing(x), [a.parts, b.parts]), "\n"))
    ==(a::Question, b::Question) = a.value.val == b.value.val
    <(a::Question, b::Question) = a.value.val < b.value.val
    <=(a::Question, b::Question) = a.value.val <= b.value.val
    >(a::Question, b::Question) = a.value.val > b.value.val
    >=(a::Question, b::Question) = a.value.val >= b.value.val
    # zero(::Type{Question}; name="Auto") = Question(name, 0.0)
    # one(::Type{Question}; name="Auto") = Question(name, 1.0)
    show(io::IO, x::Question) = print(io, join([x.name, x.codename * ": " * round(x.value.val; digits=COURSE_POINT_DECIMALPLACES), isnothing(x.parts) ? nothing : join(map(p->show(io, p), x.parts), "\n\t")], "\n"))
    float(x::Question) = x.value.val
    convert(::Type{Float64}, x::Question) = x.value.val
    promote_rule(::Type{Question}, ::Type{Float64}) = Float64
    promote_rule(::Type{Question}, ::Type{T}) where {T<:Real} = promote_rule(Float64, T)


    show(io::IO, x::Evaluation) = print(io, join(map(fn->show(io, x[fn]), fieldnames(x)), "\n"))
    float(x::Evaluation) = x.mark.delta.val / x.target.value.val
    convert(::Type{Float64}, x::Evaluation) = x.mark.delta.val / x.target.value.val
    promote_rule(::Type{Evaluation}, ::Type{Float64}) = Float64
    promote_rule(::Type{Evaluation}, ::Type{T}) where {T<:Real} = promote_rule(Float64, T)


    show(io::IO, x::Rubric) = print(io, join([x.name, x.codename * ": ", join(map(m->show(io, m), x.metrics), "\n\t")], "\n"))
    float(x::Rubric) = float.(x.metrics)
    convert(::Type{Float64}, x::Rubric) = float.(x.metrics)
    promote_rule(::Type{Rubric}, ::Type{Float64}) = Float64
    promote_rule(::Type{Rubric}, ::Type{T}) where {T<:Real} = promote_rule(Float64, T)

    # +(a::Assignment, b::Assignment) = a.value + b.value
    # -(a::Assignment, b::Assignment) = a.value - b.value
    # ==(a::Assignment, b::Assignment) = a.value == b.value
    # <(a::Assignment, b::Assignment) = a.value < b.value
    # <=(a::Assignment, b::Assignment) = a.value <= b.value
    # >(a::Assignment, b::Assignment) = a.value > b.value
    # >=(a::Assignment, b::Assignment) = a.value >= b.value
    show(io::IO, x::Assignment) = print(io, join(["Name: " * x.name, "Value: " * x.value, "Due: " * x.due, "Category: " * x.category, "Is Group? " * x.is_group, "Questions: " * join(map(q->show(io, q), x.questions), "\n\t"), "Codename: " * x.codename], "\n"))
    float(x::Assignment) = x.value.val
    convert(::Type{Float64}, x::Assignment) = x.value.val
    promote_rule(::Type{Assignment}, ::Type{Float64}) = Float64
    promote_rule(::Type{Assignment}, ::Type{T}) where {T<:Real} = promote_rule(Float64, T)



## grades.jl
    +(a::Score, b::Score) = ((e, v) = (a.earned + b.earned, a.value + b.value); p = e / v; Score(e, v, p, credit2lettergrade(p), join(map(x->x.comment, [a, b]), "\n")))
    # +(a::Score, b::Score...) = a + reduce(+, b)
    -(a::Score, b::Score) = ((e, v) = (a.earned - b.earned, a.value - b.value); p = e / v; Score(e, v, p, credit2lettergrade(p), join(map(x->x.comment, [a, b]), "\n")))
    # -(a::Score, b::Score...) = a + reduce(-, b)
    # *(a::Score, b::Score) = Score(a.x * b.x)
    # /(a::Score, b::Score) = Score(a.x / b.x)
    ==(a::Score, b::Score) = a.percent == b.percent
    <(a::Score, b::Score) = a.percent < b.percent
    <=(a::Score, b::Score) = a.percent <= b.percent
    >(a::Score, b::Score) = a.percent > b.percent
    >=(a::Score, b::Score) = a.percent >= b.percent
    float(x::Score) = x.percent.val
    convert(::Type{Float64}, x::Score) = x.percent.val
    promote_rule(::Type{Score}, ::Type{Float64}) = Float64
    promote_rule(::Type{Score}, ::Type{T}) where {T<:Real} = promote_rule(Float64, T)


    +(a::Score, b::Real) = Score(a.earned + Float64(b), a.value)
    +(a::Real, b::Score) = Score(Float64(a) + b.earned, b.value)
    -(a::Score, b::Real) = Score(a.earned - Float64(b), a.value)
    *(a::Score, b::Real) = Score(a.earned * Float64(b), a.value)
    *(a::Real, b::Score) = Score(Float64(a) * b.earned, b.value)
    /(a::Score, b::Real) = Score(a.earned / Float64(b), a.value)

    +(a::Score, b::Percent) = Score(a.percent + b, a.value)
    +(a::Percent, b::Score) = Score(a + b.percent, b.value)
    -(a::Score, b::Percent) = Score(a.percent - b, a.value)
    *(a::Score, b::Percent) = Score(a.percent * b, a.value)
    *(a::Percent, b::Score) = Score(a * b.percent, b.value)
    /(a::Score, b::Percent) = Score(a.percent / b, a.value)


    show(io::IO, x::Submission) = print(io, join(["  Submitted: " * x.submitted, "      Score: " * x.score, "Evaluations: ", join(x.evaluations, "\n\t")], "\n"))


    +(a::Submission, b::Real) = Submission(a.submitted, a.score + Float64(b), a.evaluations)
    +(a::Real, b::Submission) = b + Float64(a)
    -(a::Submission, b::Real) = Submission(a.submitted, a.score - Float64(b), a.evaluations)
    *(a::Submission, b::Real) = Submission(a.submitted, a.score * Float64(b), a.evaluations)
    *(a::Real, b::Submission) = b * Float64(a)
    /(a::Submission, b::Real) = Submission(a.submitted, a.score / Float64(b), a.evaluations)

    +(a::Submission, b::Percent) = Submission(a.submitted, a.score + b, a.evaluations)
    +(a::Percent, b::Submission) = b + a
    -(a::Submission, b::Percent) = Submission(a.submitted, a.score - b, a.evaluations)
    *(a::Submission, b::Percent) = Submission(a.submitted, a.score * b, a.evaluations)
    *(a::Percent, b::Submission) = b * a
    /(a::Submission, b::Percent) = Submission(a.submitted, a.score / b, a.evaluations)


    show(io::IO, x::Grade) = print(io, join(map(fn->x[fn], fieldnames(x)), "\n"))


    +(a::Grade, b::Real) = Grade(x.who, x.assignment, Submission(a.submitted, a.score + Float64(b), a.evaluations))
    +(a::Real, b::Grade) = Grade(x.who, x.assignment, b + Float64(a))
    -(a::Grade, b::Real) = Grade(x.who, x.assignment, Submission(a.submitted, a.score - Float64(b), a.evaluations))
    *(a::Grade, b::Real) = Grade(x.who, x.assignment, Submission(a.submitted, a.score * Float64(b), a.evaluations))
    *(a::Real, b::Grade) = Grade(x.who, x.assignment, b * Float64(a))
    /(a::Grade, b::Real) = Grade(x.who, x.assignment, Submission(a.submitted, a.score / Float64(b), a.evaluations))

    +(a::Grade, b::Percent) = Grade(x.who, x.assignment, Submission(a.submitted, a.score + b, a.evaluations))
    +(a::Percent, b::Grade) = Grade(x.who, x.assignment, b + a)
    -(a::Grade, b::Percent) = Grade(x.who, x.assignment, Submission(a.submitted, a.score - b, a.evaluations))
    *(a::Grade, b::Percent) = Grade(x.who, x.assignment, Submission(a.submitted, a.score * b, a.evaluations))
    *(a::Percent, b::Grade) = Grade(x.who, x.assignment, b * a)
    /(a::Grade, b::Percent) = Grade(x.who, x.assignment, Submission(a.submitted, a.score / b, a.evaluations))


    function convert(::Type{Dict}, x::Grade)
        dict_student = Dict(x.student)
        dict_assignment = Dict(x.assignment)
        dict_submission = Dict()
        dict_submission["assignment"] = dict_assignment
        dict_submission["datetime"] = x.submission.datetime
        dict_submission["score"] = Dict(x.submission.score)
        return Dict(
            "student"       => dict_student,
            "assignment"    => dict_assignment,
            "submission"    => dict_submission,
        )
    end
