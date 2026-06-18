public GradeCategory, determine_category
export LetterGrade
public grade_value, credit2letter

@enum GradeCategory begin
    A_plus
    A
    A_minus
    B_plus
    B
    B_minus
    C_plus
    C
    C_minus
    D_plus
    D
    D_minus
    F
    FN          # Failure for Non-attendance
    W           # Withdrawn
    I           # Incomplete
end

function determine_category(g::String)::GradeCategory
    g = uppercase(g)
    g == "A+"  && return A_plus
    g == "A"   && return A
    g == "A-"  && return A_minus
    g == "B+"  && return B_plus
    g == "B"   && return B
    g == "B-"  && return B_minus
    g == "C+"  && return C_plus
    g == "C"   && return C
    g == "C-"  && return C_minus
    g == "D+"  && return D_plus
    g == "D"   && return D
    g == "D-"  && return D_minus
    g == "F"   && return F
    g == "FN"  && return FN
    g == "W"   && return W
    g == "I"   && return I
    @error "Given string cannot be parsed as grade." string=g
end

"""
    LetterGrade

A validated 1- or 2-character academic letter grade (e.g. "A", "A+", "B-", "FN", "I", "W", etc.).
Enforces length and provides nice printing/conversion.
"""
struct LetterGrade
    value::String
    category::GradeCategory   # for fast filtering/dispatch

    function LetterGrade(s::AbstractString, g::GradeCategory) # inner constructor for validation
        s = strip(string(s))
        len = length(s)
        if len == 0 || len > 2
            throw(ArgumentError("LetterGrade must be 1 or 2 characters, got: '$s'"))
        end
        # Optional: add more validation (only letters + +/-
        if !all(c -> isletter(c) || c in ('+', '-', 'N', 'I', 'W'), s)
            @warn "Unusual grade characters in '$s'"
        end

        return new(s, determine_category(s))
    end
end
LetterGrade(s::AbstractString) = LetterGrade(s, determine_category(s))

# Example mapping for numerical sorting / GPA
function grade_value(g::LetterGrade)::Float64
    base = Dict(
        "A" => 4.0, "A+" => 4.33, "A-" => 3.67,
        "B" => 3.0, "B+" => 3.33, "B-" => 2.67,
        "C" => 2.0, "C+" => 2.33, "C-" => 1.67,
        "D" => 1.0, "D+" => 1.33, "D-" => 0.67,
        "F" => 0.0, "FN" => 0.0, "I" => NaN, "W" => NaN
    )
    get(base, g.value, 0.0)
end

# credit2letter(p::Percent) = convert(Char, p)
function credit2letter(p::Percent)
    val = p.val * 100
    if      val >= 97   LetterGrade("A+")
    elseif  val >= 93   LetterGrade("A")
    elseif  val >= 90   LetterGrade("A-")
    elseif  val >= 87   LetterGrade("B+")
    elseif  val >= 83   LetterGrade("B")
    elseif  val >= 80   LetterGrade("B-")
    elseif  val >= 77   LetterGrade("C+")
    elseif  val >= 73   LetterGrade("C")
    elseif  val >= 70   LetterGrade("C-")
    elseif  val >= 67   LetterGrade("D+")
    elseif  val >= 63   LetterGrade("D")
    elseif  val >= 60   LetterGrade("D-")
    elseif  val >= 0    LetterGrade("F")
    else                LetterGrade("FN")
    end
end
credit2letter(p::T, v::T) where {T<:Point} = credit2letter(p / v)
credit2letter(p::T, v::T) where {T<:Real} = credit2letter(Point(p) / Point(v))
