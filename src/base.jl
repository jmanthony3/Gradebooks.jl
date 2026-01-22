import Base: +, -, *, /, ==, <, <=, >, >=, zero, one, convert, promote_rule, show



const Dictable = Union{AbstractPerson,Course,AbstractAssignment,AbstractScore}
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
show(io::IO, x::Instructor) = print(io, join(["Name: " * x.name, "Email: " * x.email, "Phone: " * x.phone, "Job Title: " * x.job_title, "Organization: " * x.organization, "ID: " * x.id], "\n"))
show(io::IO, x::Student) = print(io, join(["Name: " * x.name * " (" * x.discipline * ")", "Email: " * x.email, "Phone: " * x.phone, "Organization: " * x.organization, "ID: " * x.id], "\n"))



## Points/Percentage/Grant/Subtract/Score
+(a::Points, b::Points) = Points(a.val + b.val)
-(a::Points, b::Points) = Points(a.val - b.val)
# *(a::Points, b::Points) = Points(a.x * b.x)
/(a::Points, b::Points) = Percentage(a.val / b.val)
==(a::Points, b::Points) = a.val == b.val
<(a::Points, b::Points) = a.val < b.val
<=(a::Points, b::Points) = a.val <= b.val
>(a::Points, b::Points) = a.val > b.val
>=(a::Points, b::Points) = a.val >= b.val
zero(::Type{Points}) = Points(0.0)
one(::Type{Points}) = Points(1.0)
show(io::IO, x::Points) = print(io, x.val)
Base.float(x::Points) = x.val
convert(::Type{Float64}, x::Points) = x.val
promote_rule(::Type{Points}, ::Type{Float64}) = Float64
promote_rule(::Type{Points}, ::Type{T}) where {T<:Real} = promote_rule(Float64, T)

+(a::Percentage, b::Percentage) = Percentage(a.val + b.val)
-(a::Percentage, b::Percentage) = Percentage(a.val - b.val)
*(a::Percentage, b::Percentage) = Percentage(a.val * b.val)
/(a::Percentage, b::Percentage) = Percentage(a.val / b.val)
==(a::Percentage, b::Percentage) = a.val == b.val
<(a::Percentage, b::Percentage) = a.val < b.val
<=(a::Percentage, b::Percentage) = a.val <= b.val
>(a::Percentage, b::Percentage) = a.val > b.val
>=(a::Percentage, b::Percentage) = a.val >= b.val
zero(::Type{Percentage}) = Percentage(0.0)
one(::Type{Percentage}) = Percentage(1.0)
show(io::IO, x::Percentage) = print(io, 100x.val, " %")
Base.float(x::Percentage) = x.val
convert(::Type{Float64}, x::Percentage) = x.val
convert(::Type{Char}, x::Percentage) = (x >= 0.90 ? 'A' : (x >= 0.80 ? 'B' : (x >= 0.70 ? 'C' : (x >= 0.60 ? 'D' : 'F'))))
promote_rule(::Type{Percentage}, ::Type{Float64}) = Float64
promote_rule(::Type{Percentage}, ::Type{T}) where {T<:Real} = promote_rule(Float64, T)

*(a::Points, b::Percentage) = a.val * b.val
*(a::Percentage, b::Points) = b * a

+(a::Grant, b::Grant) = Grant(a.mark + b.mark) # , a.value + b.value)
-(a::Grant, b::Grant) = Grant(a.mark - b.mark) # , a.value - b.value)
# *(a::Grant, b::Grant) = Points(a.x * b.x)
# *(a::Grant{Percentage}, b::Grant{Percentage}) = Grant(a.mark * b.mark, a.value + b.value)
# /(a::Grant{Points}, b::Grant{Points}) = a.mark / b.mark
# /(a::Grant{Percentage}, b::Grant{Percentage}) = Grant(a.mark / b.mark, a.value - b.value)
==(a::Grant, b::Grant) = a.mark == b.mark
<(a::Grant, b::Grant) = a.mark < b.mark
<=(a::Grant, b::Grant) = a.mark <= b.mark
>(a::Grant, b::Grant) = a.mark > b.mark
>=(a::Grant, b::Grant) = a.mark >= b.mark
show(io::IO, x::Grant) = print(io, x.mark) # , " / ", x.value)
Base.float(x::Grant) = x.mark
convert(::Type{Float64}, x::Grant) = x.mark
promote_rule(::Type{Grant}, ::Type{Float64}) = Float64
promote_rule(::Type{Grant}, ::Type{T}) where {T<:Real} = promote_rule(Float64, T)

# *(a::Grant, b::Percentage) = a.val * b.val
# *(a::Percentage, b::Grant) = b * a

+(a::Subtract, b::Subtract) = Subtract(a.mark + b.mark) # , a.value + b.value)
-(a::Subtract, b::Subtract) = Subtract(a.mark - b.mark) # , a.value - b.value)
# *(a::Subtract, b::Subtract) = Points(a.x * b.x)
# *(a::Subtract{Percentage}, b::Subtract{Percentage}) = Subtract(a.mark * b.mark, a.value + b.value)
# /(a::Subtract{Points}, b::Subtract{Points}) = a.mark / b.mark
# /(a::Subtract{Percentage}, b::Subtract{Percentage}) = Subtract(a.mark / b.mark, a.value - b.value)
==(a::Subtract, b::Subtract) = a.mark == b.mark
<(a::Subtract, b::Subtract) = a.mark < b.mark
<=(a::Subtract, b::Subtract) = a.mark <= b.mark
>(a::Subtract, b::Subtract) = a.mark > b.mark
>=(a::Subtract, b::Subtract) = a.mark >= b.mark
show(io::IO, x::Subtract) = print(io, x.mark) # , " / ", x.value)
Base.float(x::Subtract) = x.mark
convert(::Type{Float64}, x::Subtract) = x.mark
promote_rule(::Type{Subtract}, ::Type{Float64}) = Float64
promote_rule(::Type{Subtract}, ::Type{T}) where {T<:Real} = promote_rule(Float64, T)

# *(a::Subtract, b::Percentage) = a.val * b.val
# *(a::Percentage, b::Subtract) = b * a

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

*(a::Score, b::Percentage) = Score(a.score * b, a.value)
*(a::Percentage, b::Score) = b * a



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


*(a::Submission, b::Percentage) = Submission(a.submitted, a.score * b)
*(a::Percentage, b::Submission) = b * a
*(a::Grade, b::Percentage) = Grade(a.student, a.assignment, a.submission * b)
*(a::Percentage, b::Grade) = b * a



## Gradebook
*(A::Matrix{Percentage}, b::Vector{Assignment}) = float.(A) * float.(b)
/(A::Gradebook, b::Vector{Assignment}) = (A = Matrix(A.data); isa(eltype(A), Points) ? Percentage.(A ./ transpose(b)) : (@error "Cannot divide because eltype(A) ≠ Points" eltype(A)))
*(A::Gradebook, b::Vector{Assignment}) = (A = Matrix(A.data); isa(eltype(A), Percentage) ? (A * b) : (isa(eltype(A), Points) ? ((A / b) * b) : (@error "Cannot multiply because eltype(A) is neither Points nor Percentage" eltype(A))))
