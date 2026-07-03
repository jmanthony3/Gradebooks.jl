import Base: +, -, *, /, ==, <, <=, >, >=, isless, zero, one, float, convert, promote_rule, length, iterate, parse, show



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



## credit.jl
    *(x::Real, ::Type{Point}) = Point(Float64(x))

    +(a::Point, b::Point) = Point(a.value + b.value)
    -(a::Point, b::Point) = Point(a.value - b.value)
    # *(a::Point, b::Point) = Point(a.x * b.x)
    /(a::Point, b::Point) = Percent(a.value / b.value)
    ==(a::Point, b::Point) = a.value == b.value
    <(a::Point, b::Point) = a.value < b.value
    <=(a::Point, b::Point) = a.value <= b.value
    >(a::Point, b::Point) = a.value > b.value
    >=(a::Point, b::Point) = a.value >= b.value
    isless(a::Point, b::Point) = a.value < b.value
    zero(::Type{Point}) = Point(0.0)
    one(::Type{Point}) = Point(1.0)
    float(x::Point) = x.value
    convert(::Type{Float64}, x::Point) = x.value
    convert(::Type{Point}, x::Real) = Point(x)
    convert(::Type{Point}, x::Point) = x
    promote_rule(::Type{Point}, ::Type{Float64}) = Float64
    promote_rule(::Type{Point}, ::Type{T}) where {T<:Real} = promote_rule(Float64, T)
    length(x::Point) = length(x.value)
    function iterate(x::Point, state=1)
        state > length(x.value) && return nothing
        return x.value[state], state + 1
    end
    parse(::Type{Point}, s::AbstractString) = Point(parse(Float64, s))
    show(io::IO, x::Point) = print(io, round(x.value; digits=COURSE_POINT_DECIMALPLACES))

    +(a::Point, b::Real) = Point(a.value + Float64(b))
    +(a::Real, b::Point) = Point(Float64(a) + b.value)
    -(a::Point, b::Real) = Point(a.value - Float64(b))
    *(a::Point, b::Real) = Point(a.value * Float64(b))
    *(a::Real, b::Point) = Point(Float64(a) * b.value)
    /(a::Point, b::Real) = Point(a.value / Float64(b))


    *(x::Real, ::Type{Percent}) = Percent(Float64(x))

    +(a::Percent, b::Percent) = Percent(a.value + b.value; normalized=false)
    -(a::Percent, b::Percent) = Percent(a.value - b.value; normalized=false)
    *(a::Percent, b::Percent) = Percent(a.value * b.value; normalized=false)
    /(a::Percent, b::Percent) = Percent(a.value / b.value; normalized=false)
    ==(a::Percent, b::Percent) = a.value == b.value
    <(a::Percent, b::Percent) = a.value < b.value
    <=(a::Percent, b::Percent) = a.value <= b.value
    >(a::Percent, b::Percent) = a.value > b.value
    >=(a::Percent, b::Percent) = a.value >= b.value
    isless(a::Percent, b::Percent) = a.value < b.value
    zero(::Type{Percent}) = Percent(0.0)
    one(::Type{Percent}) = Percent(1.0)
    float(x::Percent) = x.value
    convert(::Type{Float64}, x::Percent) = x.value
    # convert(::Type{Char}, x::Percent) = (x >= 0.90 ? 'A' : (x >= 0.80 ? 'B' : (x >= 0.70 ? 'C' : (x >= 0.60 ? 'D' : 'F'))))
    promote_rule(::Type{Percent}, ::Type{Float64}) = Float64
    promote_rule(::Type{Percent}, ::Type{T}) where {T<:Real} = promote_rule(Float64, T)
    length(x::Percent) = length(x.value)
    function iterate(x::Percent, state=1)
        state > length(x.value) && return nothing
        return x.value[state], state + 1
    end
    parse(::Type{Percent}, s::AbstractString) = Percent(parse(Float64, s); normalized=false)
    show(io::IO, x::Percent) = print(io, round(x.value; digits=COURSE_POINT_DECIMALPLACES), " %")


    *(a::Point, b::Percent) = Point(a.value * b.value)
    *(a::Percent, b::Point) = Point(a.value * b.value)


    +(a::Mark, b::Mark) = Mark(a.delta + b.delta; comment=join([a.comment, b.comment], "\n")) # , a.value + b.value)
    -(a::Mark, b::Mark) = Mark(a.delta - b.delta; comment=join([a.comment, b.comment], "\n")) # , a.value - b.value)
    # *(a::Mark, b::Mark) = Mark(a.delta * b.delta; comment=join([a.comment, b.comment], "\n")) # , a.value * b.value)
    # /(a::Mark, b::Mark) = Mark(a.delta / b.delta; comment=join([a.comment, b.comment], "\n")) # , a.value / b.value)
    ==(a::Mark, b::Mark) = a.delta == b.delta
    <(a::Mark, b::Mark) = a.delta < b.delta
    <=(a::Mark, b::Mark) = a.delta <= b.delta
    >(a::Mark, b::Mark) = a.delta > b.delta
    >=(a::Mark, b::Mark) = a.delta >= b.delta
    isless(a::Mark, b::Mark) = a.delta < b.delta
    float(x::Mark) = x.delta.value
    convert(::Type{Float64}, x::Mark) = x.delta.value
    promote_rule(::Type{Mark}, ::Type{Float64}) = Float64
    promote_rule(::Type{Mark}, ::Type{T}) where {T<:Real} = promote_rule(Float64, T)
    length(x::Mark) = length(x.delta)
    function iterate(x::Mark, state=1)
        state > length(x.delta) && return nothing
        return x.delta[state], state + 1
    end
    show(io::IO, x::Mark) = print(io, x.delta, " # ", x.comment)


    +(a::Mark, b::Real) = Mark(a.delta + Float64(b), a.comment)
    +(a::Real, b::Mark) = Mark(Float64(a) + b.delta, b.comment)
    -(a::Mark, b::Real) = Mark(a.delta - Float64(b), a.comment)
    *(a::Mark, b::Real) = Mark(a.delta * Float64(b), a.comment)
    *(a::Real, b::Mark) = Mark(Float64(a) * b.delta, b.comment)
    /(a::Mark, b::Real) = Mark(a.delta / Float64(b), a.comment)

    +(a::Mark, b::Point) = Mark(a.delta + b, a.comment)
    +(a::Point, b::Mark) = Mark(a + b.delta, b.comment)
    -(a::Mark, b::Point) = Mark(a.delta - b, a.comment)
    *(a::Mark, b::Point) = Mark(a.delta * b, a.comment)
    *(a::Point, b::Mark) = Mark(a * b.delta, b.comment)
    /(a::Mark, b::Point) = Mark(a.delta / b, a.comment)

    +(a::Mark, b::Percent) = Mark(a.delta + b, a.comment)
    +(a::Percent, b::Mark) = Mark(a + b.delta, b.comment)
    -(a::Mark, b::Percent) = Mark(a.delta - b, a.comment)
    *(a::Mark, b::Percent) = Mark(a.delta * b, a.comment)
    *(a::Percent, b::Mark) = Mark(a * b.delta, b.comment)
    /(a::Mark, b::Percent) = Mark(a.delta / b, a.comment)



## letter_grades.jl
    float(x::GradeLevel) = Float64(quality_points(x))
    convert(::Type{Float64}, x::GradeLevel) = Float64(quality_points(x))
    promote_rule(::Type{GradeLevel}, ::Type{Float64}) = Float64
    promote_rule(::Type{GradeLevel}, ::Type{T}) where {T<:Real} = promote_rule(Float64, T)
    show(io::IO, g::GradeLevel) = print(io, determine_level(g))


    ==(a::LetterGrade, b::LetterGrade) = a.quality_points == b.quality_points
    <(a::LetterGrade, b::LetterGrade) = a.quality_points < b.quality_points
    <=(a::LetterGrade, b::LetterGrade) = a.quality_points <= b.quality_points
    >(a::LetterGrade, b::LetterGrade) = a.quality_points > b.quality_points
    >=(a::LetterGrade, b::LetterGrade) = a.quality_points >= b.quality_points
    isless(a::LetterGrade, b::LetterGrade) = a.quality_points < b.quality_points
    float(x::LetterGrade) = x.quality_points
    Base.string(x::LetterGrade) = x.string
    convert(::Type{Float64}, x::LetterGrade) = x.quality_points
    convert(::Type{String}, x::LetterGrade) = x.string
    convert(::Type{LetterGrade}, x::AbstractString) = LetterGrade(x)
    promote_rule(::Type{LetterGrade}, ::Type{Float64}) = Float64
    promote_rule(::Type{LetterGrade}, ::Type{T}) where {T<:Real} = promote_rule(Float64, T)
    length(x::LetterGrade) = length(x.quality_points)
    function iterate(x::LetterGrade, state=1)
        state > length(x.quality_points) && return nothing
        return x.quality_points[state], state + 1
    end
    show(io::IO, x::LetterGrade) = print(io, x.string)

    *(a::LetterGrade, b::Real) = gpa(a, b)
    *(a::Real, b::LetterGrade) = gpa(b, a)



## people.jl
    show(io::IO, x::Person) = print(io, join(["              Name: " * x.name, "           Aliases: " * (!isempty(x.name_aliases) ? join(x.name_aliases, ", ") : ""), "             Email: " * x.email, "             Phone: " * x.phone, "      Organization: " * x.organization, "                ID: " * x.id, "              Code: " * string(x.codename)], "\n"))
    show(io::IO, x::Instructor) = print(io, join([repr(x.person), "         Job Title: " * x.job_title], "\n"))
    show(io::IO, x::Student) = print(io, join([repr(x.person), "        Discipline: " * x.discipline, "        Enrollment: " * string(x.enrollment_status), "       Final Grade: " * (!isnothing(x.final_grade) ? repr(x.final_grade) : "n/a"), "   Withdrawal Date: " * string(x.withdrawal_date), "             Notes: ", x.notes], "\n"))
    length(x::Roster) = length(x.students)
    function iterate(x::Roster, state=1)
        state > length(x.students) && return nothing
        return x.students[state], state + 1
    end
    show(io::IO, x::Roster) = print(io, join(map(s->join(["              Name: " * s.person.name, "\t           Aliases: " * (!isempty(s.person.name_aliases) ? join(s.person.name_aliases, ", ") : ""), "\t             Email: " * s.person.email, "\t             Phone: " * s.person.phone, "\t      Organization: " * s.person.organization, "\t                ID: " * s.person.id, "\t              Code: " * string(s.person.codename), "\t        Discipline: " * s.discipline, "\t        Enrollment: " * string(s.enrollment_status), "\t       Final Grade: " * repr(s.final_grade), "\t   Withdrawal Date: " * string(s.withdrawal_date), "\t             Notes: ", s.notes], "\n"), x.students), "\n"))
    length(x::Team) = length(x.roster.students)
    function iterate(x::Team, state=1)
        state > length(x.roster.students) && return nothing
        return x.roster.students[state], state + 1
    end
    show(io::IO, x::Team) = print(io, x.name, " (", x.codename, "):", first(x.roster.students))



## assignments.jl
    # +(a::Question, b::Question) = a.value + b.value # Question(join([a.name, b.name], "\n"), a.value + b.value, join(filter(x->!isnothing(x), [a.parts, b.parts]), "\n"))
    # -(a::Question, b::Question) = a.value - b.value # Question(join([a.name, b.name], "\n"), a.value - b.value, join(filter(x->!isnothing(x), [a.parts, b.parts]), "\n"))
    ==(a::Question, b::Question) = a.value.value == b.value.value
    <(a::Question, b::Question) = a.value.value < b.value.value
    <=(a::Question, b::Question) = a.value.value <= b.value.value
    >(a::Question, b::Question) = a.value.value > b.value.value
    >=(a::Question, b::Question) = a.value.value >= b.value.value
    isless(a::Question, b::Question) = a.value.value < b.value.value
    # zero(::Type{Question}; name="Auto") = Question(name, 0.0)
    # one(::Type{Question}; name="Auto") = Question(name, 1.0)
    float(x::Question) = x.value.value
    convert(::Type{Float64}, x::Question) = x.value.value
    promote_rule(::Type{Question}, ::Type{Float64}) = Float64
    promote_rule(::Type{Question}, ::Type{T}) where {T<:Real} = promote_rule(Float64, T)
    length(x::Question) = (!isnothing(x.parts) ? length(x.parts) : 1)
    function iterate(x::Question, state=1)
        state > (!isnothing(x.parts) ? length(x.parts) : 1) && return nothing
        return x.parts[state], state + 1
    end
    show(io::IO, x::Question) = print(io, join([x.name, string(x.codename) * ": " * string(round(x.value.value; digits=COURSE_POINT_DECIMALPLACES)), isnothing(x.parts) ? nothing : join(map(p->show(io, p), x.parts), "\n\t")], "\n"))


    float(x::Evaluation) = x.mark.delta.value / x.target.value.value
    convert(::Type{Float64}, x::Evaluation) = x.mark.delta.value / x.target.value.value
    promote_rule(::Type{Evaluation}, ::Type{Float64}) = Float64
    promote_rule(::Type{Evaluation}, ::Type{T}) where {T<:Real} = promote_rule(Float64, T)
    length(x::Evaluation) = length(x.mark)
    function iterate(x::Evaluation, state=1)
        state > length(x.mark) && return nothing
        return x.mark[state], state + 1
    end
    show(io::IO, x::Evaluation) = print(io, join(map(fn->show(io, x[fn]), fieldnames(x)), "\n"))


    float(x::Rubric) = float.(x.metrics)
    convert(::Type{Float64}, x::Rubric) = float.(x.metrics)
    promote_rule(::Type{Rubric}, ::Type{Float64}) = Float64
    promote_rule(::Type{Rubric}, ::Type{T}) where {T<:Real} = promote_rule(Float64, T)
    length(r::Rubric) = length(r.metrics)
    function iterate(r::Rubric, state=1)
        state > length(r.metrics) && return nothing
        return r.metrics[state], state + 1
    end
    show(io::IO, x::Rubric) = print(io, join([x.name, string(x.codename) * ": ", join(map(m->show(io, m), x.metrics), "\n\t")], "\n"))

    # +(a::Assignment, b::Assignment) = a.value + b.value
    # -(a::Assignment, b::Assignment) = a.value - b.value
    # ==(a::Assignment, b::Assignment) = a.value == b.value
    # <(a::Assignment, b::Assignment) = a.value < b.value
    # <=(a::Assignment, b::Assignment) = a.value <= b.value
    # >(a::Assignment, b::Assignment) = a.value > b.value
    # >=(a::Assignment, b::Assignment) = a.value >= b.value
    float(x::Assignment) = x.value.value
    convert(::Type{Float64}, x::Assignment) = x.value.value
    promote_rule(::Type{Assignment}, ::Type{Float64}) = Float64
    promote_rule(::Type{Assignment}, ::Type{T}) where {T<:Real} = promote_rule(Float64, T)
    length(x::Assignment) = length(x.questions)
    function iterate(x::Assignment, state=1)
        state > length(x.questions) && return nothing
        return x.questions[state], state + 1
    end
    show(io::IO, x::Assignment) = print(io, join(["Name: " * x.name, "Value: " * repr(x.value), "Due: " * string(x.due), "Category: " * string(x.category), "Is Group? " * string(x.is_group), "Questions: " * join(map(q->show(io, q), x.questions), "\n\t"), "Codename: " * string(x.codename)], "\n"))



## Gradebooks.jl
    length(x::Course) = length(x.assignments)
    function iterate(x::Course, state=1)
        state > length(x.assignments) && return nothing
        return x.assignments[state], state + 1
    end
    show(io::IO, x::Course) = print(io, join(["              Code: " * string(x.code), "            Number: " * string(x.number), "              Name: " * x.name, "           Credits: " * string(x.credits), "  # of Assignments: " * join(map(a->show(io, a), x.assignments), "\n"), "          Codename: " * string(x.codename)], "\n"))
    show(io::IO, x::Term) = print(io, join(["             Name: " * x.name, "     Calendar Type: " * string(x.calendar_type), "              Year: " * string(x.year), "        Start Date: " * string(x.start), "       Finish Date: " * string(x.finish), "              Code: " * string(x.code), "\t          Metadata: ", x.metadata], "\n"))
    show(io::IO, x::Class) = print(io, join([repr(x.course), repr(x.term), "           Section: " * string(x.section), "         Frequency: " * join(x.frequency, ", "), "        Start Time: " * string(x.time_start), "       Finish Time: " * string(x.time_finish), "     Duration Time: " * string(x.time_duration), "Number of Lectures: " * string(length(x.lectures)), "  Codename (Short): " * string(x.codename_short), "   Codename (Long): " * string(x.codename_long), "Primary Instructor: " * repr(x.primary_instructor), "       Instructors: \n\t" * join(map(y->show(io, y), x.instructors), "\n\t"), "            Roster: " * repr(x.roster)], "\n"))



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
    isless(a::Score, b::Score) = a.percent < b.percent
    float(x::Score) = x.percent.value
    convert(::Type{Float64}, x::Score) = x.percent.value
    promote_rule(::Type{Score}, ::Type{Float64}) = Float64
    promote_rule(::Type{Score}, ::Type{T}) where {T<:Real} = promote_rule(Float64, T)
    length(x::Score) = length(x.percent)
    function iterate(x::Score, state=1)
        state > length(x.percent) && return nothing
        return x.percent[state], state + 1
    end
    show(io::IO, x::Score) = print(io, string(x.earned) * " / " * string(x.value) * " (" * string(x.percent) * ", " * repr(x.letter) *  ")" * (isempty(x.comment) ? "" : "# ") * x.comment)


    +(a::Score, b::Real) = Score(a.earned + Float64(b), a.value)
    +(a::Real, b::Score) = Score(Float64(a) + b.earned, b.value)
    -(a::Score, b::Real) = Score(a.earned - Float64(b), a.value)
    *(a::Score, b::Real) = Score(a.earned * Float64(b), a.value)
    *(a::Real, b::Score) = Score(Float64(a) * b.earned, b.value)
    /(a::Score, b::Real) = Score(a.earned / Float64(b), a.value)

    +(a::Score, b::Point) = Score(a.earned + b, a.value)
    +(a::Point, b::Score) = Score(a + b.earned, b.value)
    -(a::Score, b::Point) = Score(a.earned - b, a.value)
    *(a::Score, b::Point) = Score(a.earned * b, a.value)
    *(a::Point, b::Score) = Score(a * b.earned, b.value)
    /(a::Score, b::Point) = Score(a.earned / b, a.value)

    +(a::Score, b::Percent) = Score(a.percent + b, a.value)
    +(a::Percent, b::Score) = Score(a + b.percent, b.value)
    -(a::Score, b::Percent) = Score(a.percent - b, a.value)
    *(a::Score, b::Percent) = Score(a.percent * b, a.value)
    *(a::Percent, b::Score) = Score(a * b.percent, b.value)
    /(a::Score, b::Percent) = Score(a.percent / b, a.value)


    ==(a::Submission, b::Submission) = a.score.percent == b.score.percent
    <(a::Submission, b::Submission) = a.score.percent < b.score.percent
    <=(a::Submission, b::Submission) = a.score.percent <= b.score.percent
    >(a::Submission, b::Submission) = a.score.percent > b.score.percent
    >=(a::Submission, b::Submission) = a.score.percent >= b.score.percent
    isless(a::Submission, b::Submission) = a.score.percent < b.score.percent
    length(x::Submission) = length(x.evaluations)
    function iterate(x::Submission, state=1)
        state > length(x.evaluations) && return nothing
        return x.evaluations[state], state + 1
    end
    show(io::IO, x::Submission) = print(io, join(["  Submitted: " * string(x.submitted), "      Score: " * repr(x.score), "Evaluations: ", join(map(e->show(io, e), x.evaluations), "\n\t")], "\n"))


    +(a::Submission, b::Real) = Submission(a.submitted, a.score + Float64(b), a.evaluations)
    +(a::Real, b::Submission) = b + a
    -(a::Submission, b::Real) = Submission(a.submitted, a.score - Float64(b), a.evaluations)
    *(a::Submission, b::Real) = Submission(a.submitted, a.score * Float64(b), a.evaluations)
    *(a::Real, b::Submission) = b * a
    /(a::Submission, b::Real) = Submission(a.submitted, a.score / Float64(b), a.evaluations)

    +(a::Submission, b::Point) = Submission(a.submitted, a.score + b, a.evaluations)
    +(a::Point, b::Submission) = b + a
    -(a::Submission, b::Point) = Submission(a.submitted, a.score - b, a.evaluations)
    *(a::Submission, b::Point) = Submission(a.submitted, a.score * b, a.evaluations)
    *(a::Point, b::Submission) = b * a
    /(a::Submission, b::Point) = Submission(a.submitted, a.score / b, a.evaluations)

    +(a::Submission, b::Percent) = Submission(a.submitted, a.score + b, a.evaluations)
    +(a::Percent, b::Submission) = b + a
    -(a::Submission, b::Percent) = Submission(a.submitted, a.score - b, a.evaluations)
    *(a::Submission, b::Percent) = Submission(a.submitted, a.score * b, a.evaluations)
    *(a::Percent, b::Submission) = b * a
    /(a::Submission, b::Percent) = Submission(a.submitted, a.score / b, a.evaluations)


    ==(a::Grade, b::Grade) = a.submission.score.percent == b.submission.score.percent
    <(a::Grade, b::Grade) = a.submission.score.percent < b.submission.score.percent
    <=(a::Grade, b::Grade) = a.submission.score.percent <= b.submission.score.percent
    >(a::Grade, b::Grade) = a.submission.score.percent > b.submission.score.percent
    >=(a::Grade, b::Grade) = a.submission.score.percent >= b.submission.score.percent
    isless(a::Grade, b::Grade) = a.submission.score.percent < b.submission.score.percent
    show(io::IO, x::Grade) = print(io, join(map(fn->x[fn], fieldnames(x)), "\n"))


    +(a::Grade, b::Real) = Grade(a.student, a.assignment, Submission(a.submission.submitted, a.submission.score + Float64(b), a.submission.evaluations))
    +(a::Real, b::Grade) = b + a
    -(a::Grade, b::Real) = Grade(a.student, a.assignment, Submission(a.submission.submitted, a.submission.score - Float64(b), a.submission.evaluations))
    *(a::Grade, b::Real) = Grade(a.student, a.assignment, Submission(a.submission.submitted, a.submission.score * Float64(b), a.submission.evaluations))
    *(a::Real, b::Grade) = b * a
    /(a::Grade, b::Real) = Grade(a.student, a.assignment, Submission(a.submission.submitted, a.submission.score / Float64(b), a.submission.evaluations))

    +(a::Grade, b::Point) = Grade(a.student, a.assignment, Submission(a.submission.submitted, a.submission.score + b, a.submission.evaluations))
    +(a::Point, b::Grade) = b + a
    -(a::Grade, b::Point) = Grade(a.student, a.assignment, Submission(a.submission.submitted, a.submission.score - b, a.submission.evaluations))
    *(a::Grade, b::Point) = Grade(a.student, a.assignment, Submission(a.submission.submitted, a.submission.score * b, a.submission.evaluations))
    *(a::Point, b::Grade) = b * a
    /(a::Grade, b::Point) = Grade(a.student, a.assignment, Submission(a.submission.submitted, a.submission.score / b, a.submission.evaluations))

    +(a::Grade, b::Percent) = Grade(a.student, a.assignment, Submission(a.submission.submitted, a.submission.score + b, a.submission.evaluations))
    +(a::Percent, b::Grade) = b + a
    -(a::Grade, b::Percent) = Grade(a.student, a.assignment, Submission(a.submission.submitted, a.submission.score - b, a.submission.evaluations))
    *(a::Grade, b::Percent) = Grade(a.student, a.assignment, Submission(a.submission.submitted, a.submission.score * b, a.submission.evaluations))
    *(a::Percent, b::Grade) = b * a
    /(a::Grade, b::Percent) = Grade(a.student, a.assignment, Submission(a.submission.submitted, a.submission.score / b, a.submission.evaluations))


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
