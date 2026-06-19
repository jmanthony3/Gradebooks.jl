import Base: +, -, *, /, ==, <, <=, >, >=, zero, one, convert, promote_rule, show



const Dictable = Union{AbstractPerson,Course,Assignment,Credit}
const Indictable = Union{Class,Submission,Grade}

convert(::Type{Dict}, x::Dictable) = (fns = fieldnames(x); Dict(zip(fns, getproperty.(x, fns))))
convert(::Type{DataFrame}, x::Dictable) = DataFrame(Dict(x))
function +(a::DataFrame, b::DataFrame)
    if allequal(names, [a, b])
        c = deepcopy(a)
        for name in names(a)
            c[!, name] .= a[!, name] + b[!, name]
        end
        return c
    else
        @error "Not all names of `a` occur in `b`" names(a) names(b)
    end
end

function -(a::DataFrame, b::DataFrame)
    if allequal(names, [a, b])
        c = deepcopy(a)
        for name in names(a)
            c[!, name] .= a[!, name] - b[!, name]
        end
        return c
    else
        @error "Not all names of `a` occur in `b`" names(a) names(b)
    end
end

function *(a::DataFrame, b::DataFrame)
    if allequal(names, [a, b])
        c = deepcopy(a)
        for name in names(a)
            c[!, name] .= a[!, name] * b[!, name]
        end
        return c
    else
        @error "Not all names of `a` occur in `b`" names(a) names(b)
    end
end

function /(a::DataFrame, b::DataFrame)
    if allequal(names, [a, b])
        c = deepcopy(a)
        for name in names(a)
            c[!, name] .= a[!, name] / b[!, name]
        end
        return c
    else
        @error "Not all names of `a` occur in `b`" names(a) names(b)
    end
end



## Instructor/Student
show(io::IO, x::Instructor) = print(io, join(["Name: " * x.name, "Email: " * x.email, "Phone: " * x.phone, "Job Title: " * x.job_title, "organization: " * x.INSTITUTION, "ID: " * x.id], "\n"))
show(io::IO, x::Student) = print(io, join(["Name: " * x.name * " (" * x.discipline * ")", "Email: " * x.email, "Phone: " * x.phone, "INSTITUTION: " * x.INSTITUTION, "ID: " * x.id], "\n"))



## Points/Percentage/Grant/Subtract/Score
*(x::Real, ::Type{Point}) = Point(Float64(x))
+(a::Point, b::Point) = Point(a.val + b.val)
-(a::Point, b::Point) = Point(a.val - b.val)
# *(a::Points, b::Points) = Points(a.x * b.x)
/(a::Point, b::Point) = Percent(a.val / b.val)
==(a::Point, b::Point) = a.val == b.val
<(a::Point, b::Point) = a.val < b.val
<=(a::Point, b::Point) = a.val <= b.val
>(a::Point, b::Point) = a.val > b.val
>=(a::Point, b::Point) = a.val >= b.val
zero(::Type{Point}) = Point(0.0)
one(::Type{Point}) = Point(1.0)
show(io::IO, x::Point) = print(io, x.val)
Base.float(x::Point) = x.val
convert(::Type{Float64}, x::Point) = x.val
promote_rule(::Type{Point}, ::Type{Float64}) = Float64
promote_rule(::Type{Point}, ::Type{T}) where {T<:Real} = promote_rule(Float64, T)

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
show(io::IO, x::Percent) = print(io, x.val, " %")
Base.float(x::Percent) = x.val
convert(::Type{Float64}, x::Percent) = x.val
convert(::Type{Char}, x::Percent) = (x >= 0.90 ? 'A' : (x >= 0.80 ? 'B' : (x >= 0.70 ? 'C' : (x >= 0.60 ? 'D' : 'F'))))
promote_rule(::Type{Percent}, ::Type{Float64}) = Float64
promote_rule(::Type{Percent}, ::Type{T}) where {T<:Real} = promote_rule(Float64, T)

*(a::Point, b::Percent) = Point(a.val * b.val)
*(a::Percent, b::Point) = b * a

+(a::T, b::T) where {T<:Mark} = Mark(a.delta + b.delta; comment=join([a.comment, b.comment], "\n")) # , a.value + b.value)
-(a::T, b::T) where {T<:Mark} = Mark(a.delta - b.delta; comment=join([a.comment, b.comment], "\n")) # , a.value - b.value)
# *(a::Grant, b::Grant) = Points(a.x * b.x)
# *(a::Grant{Percentage}, b::Grant{Percentage}) = Grant(a.mark * b.mark, a.value + b.value)
# /(a::Grant{Points}, b::Grant{Points}) = a.mark / b.mark
# /(a::Grant{Percentage}, b::Grant{Percentage}) = Grant(a.mark / b.mark, a.value - b.value)
==(a::T, b::T) where {T<:Mark} = a.mark == b.mark
<(a::T, b::T) where {T<:Mark} = a.mark < b.mark
<=(a::T, b::T) where {T<:Mark} = a.mark <= b.mark
>(a::T, b::T) where {T<:Mark} = a.mark > b.mark
>=(a::T, b::T) where {T<:Mark} = a.mark >= b.mark
show(io::IO, x::Mark) = print(io, x.mark) # , " / ", x.value)
Base.float(x::Mark) = x.delta.val
convert(::Type{Float64}, x::Mark) = x.delta.val
promote_rule(::Type{Mark}, ::Type{Float64}) = Float64
promote_rule(::Type{Mark}, ::Type{T}) where {T<:Real} = promote_rule(Float64, T)

+(a::Score, b::Score) = ((s, v) = (a.score + b.score, a.value + b.value); p = s / v; Score(s, v, p, p, join(map(x->x.comment, [a, b]), "\n")))
+(a::Score, b::Score...) = a + reduce(+, b)
-(a::Score, b::Score) = ((s, v) = (a.score - b.score, a.value - b.value); p = s / v; Score(s, v, p, p, join(map(x->x.comment, [a, b]), "\n")))
-(a::Score, b::Score...) = a + reduce(-, b)
# *(a::Score, b::Score) = Score(a.x * b.x)
# /(a::Score, b::Score) = Score(a.x / b.x)
==(a::Score, b::Score) = a.percent == b.percent
<(a::Score, b::Score) = a.percent < b.percent
<=(a::Score, b::Score) = a.percent <= b.percent
>(a::Score, b::Score) = a.percent > b.percent
>=(a::Score, b::Score) = a.percent >= b.percent
Base.float(x::Score) = x.score.val
convert(::Type{Float64}, x::Score) = x.score.val

+(a::Score, b::Point) = Score(a.score + b, a.value)
-(a::Score, b::Point) = Score(a.score - b, a.value)
*(a::Score, b::Percent) = Score(b, a.value)
*(a::Percent, b::Score) = b * a



## Assignment/Submission/Grade
+(a::Assignment, b::Assignment) = a.value + b.value
-(a::Assignment, b::Assignment) = a.value - b.value
==(a::Assignment, b::Assignment) = a.value == b.value
<(a::Assignment, b::Assignment) = a.value < b.value
<=(a::Assignment, b::Assignment) = a.value <= b.value
>(a::Assignment, b::Assignment) = a.value > b.value
>=(a::Assignment, b::Assignment) = a.value >= b.value
Base.float(x::Assignment) = x.value.val
convert(::Type{Float64}, x::Assignment) = x.value.val
promote_rule(::Type{Assignment}, ::Type{Float64}) = Float64
promote_rule(::Type{Assignment}, ::Type{T}) where {T<:Real} = promote_rule(Float64, T)

+(a::Submission, b::Submission) = a.score + b.score
-(a::Submission, b::Submission) = a.score - b.score
==(a::Submission, b::Submission) = a.score == b.score
<(a::Submission, b::Submission) = a.score < b.score
<=(a::Submission, b::Submission) = a.score <= b.score
>(a::Submission, b::Submission) = a.score > b.score
>=(a::Submission, b::Submission) = a.score >= b.score
Base.float(x::Submission) = x.score.value.val
convert(::Type{Float64}, x::Submission) = x.score
promote_rule(::Type{Submission}, ::Type{Float64}) = Float64
promote_rule(::Type{Submission}, ::Type{T}) where {T<:Real} = promote_rule(Float64, T)

# Nice show method
Base.show(io::IO, g::LetterGrade) = print(io, g.value)

# Conversion helpers
Base.String(g::LetterGrade) = g.value
Base.convert(::Type{String}, g::LetterGrade) = g.value
Base.convert(::Type{LetterGrade}, s::AbstractString) = LetterGrade(s)

# Comparison / sorting (important for gradebooks)
Base.isless(a::LetterGrade, b::LetterGrade) = quality_points(a) < quality_points(b)

+(a::Grade, b::Grade) = a.submission + b.submission
-(a::Grade, b::Grade) = a.submission - b.submission
==(a::Grade, b::Grade) = a.submission == b.submission
<(a::Grade, b::Grade) = a.submission < b.submission
<=(a::Grade, b::Grade) = a.submission <= b.submission
>(a::Grade, b::Grade) = a.submission > b.submission
>=(a::Grade, b::Grade) = a.submission >= b.submission
Base.float(x::Grade) = x.submission.score.value.val
convert(::Type{Float64}, x::Grade) = x.submission.score.value.val
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
promote_rule(::Type{Grade}, ::Type{Float64}) = Float64
promote_rule(::Type{Grade}, ::Type{T}) where {T<:Real} = promote_rule(Float64, T)


+(a::Submission, b::Point) = Submission(a.submitted, a.score + b, a.tallies)
+(a::Point, b::Submission) = b + a
-(a::Submission, b::Point) = Submission(a.submitted, a.score - b, a.tallies)
-(a::Point, b::Submission) = b - a
*(a::Submission, b::Percent) = Submission(a.submitted, a.score * b, a.tallies)
*(a::Percent, b::Submission) = b * a
+(a::Grade, b::Point) = Grade(a.student, a.assignment, a.submission + b, a.team)
+(a::Point, b::Grade) = b + a
-(a::Grade, b::Point) = Grade(a.student, a.assignment, a.submission - b, a.team)
-(a::Point, b::Grade) = b - a
*(a::Grade, b::Percent) = Grade(a.student, a.assignment, a.submission * b, a.team)
*(a::Percent, b::Grade) = b * a



## Gradebook
*(A::Matrix{Percent}, b::Vector{Assignment}) = float.(A) * float.(b)
/(A::Gradebook, b::Vector{Assignment}) = (A = Matrix(A.data); isa(eltype(A), Point) ? Percent.(A ./ transpose(b)) : (@error "Cannot divide because eltype(A) ≠ Points" eltype(A)))
*(A::Gradebook, b::Vector{Assignment}) = (A = Matrix(A.data); isa(eltype(A), Percent) ? (A * b) : (isa(eltype(A), Point) ? ((A / b) * b) : (@error "Cannot multiply because eltype(A) is neither Points nor Percentage" eltype(A))))
