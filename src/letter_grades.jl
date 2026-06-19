public GradeLevel, determine_level
export LetterGrade, credit2letter, quality_points, gpa

@enum GradeLevel begin
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

function determine_level(g::String)::GradeLevel
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
    level::GradeLevel

    function LetterGrade(s::AbstractString, g::GradeLevel) # inner constructor for validation
        s = uppercase(strip(string(s)))
        len = length(s)
        if len == 0 || len > 2
            throw(ArgumentError("LetterGrade must be 1 or 2 characters, got: \"$s\"."))
        end
        if !all(c -> isletter(c) || c in ('+', '-'), s)
            @warn "Unusual grade characters in \"$s\"."
        end

        return new(s, determine_level(s))
    end
end
LetterGrade(s::AbstractString) = LetterGrade(s, determine_level(s))

"Converts `Credit` to `LetterGrade` according to preferences `COURSE_POINT_SCALE` and `COURSE_POINT_SCALE_PLUSMINUS`."
function credit2letter(p::Percent)::LetterGrade
    val = p.val * 100
    return if COURSE_POINT_SCALE_PLUSMINUS == 0
        if      val >= 100 - 1(COURSE_POINT_SCALE/10)
            LetterGrade("A")
        elseif  val >= 100 - 2(COURSE_POINT_SCALE/10)
            LetterGrade("B")
        elseif  val >= 100 - 3(COURSE_POINT_SCALE/10)
            LetterGrade("C")
        elseif  val >= 100 - 4(COURSE_POINT_SCALE/10)
            LetterGrade("D")
        elseif  val >= 0
            LetterGrade("F")
        else
            LetterGrade("FN")
        end
    else
        if      val >= 100 - 0(COURSE_POINT_SCALE/10) - COURSE_POINT_SCALE_PLUSMINUS/10
            LetterGrade("A+")
        elseif  val >= 100 - 1(COURSE_POINT_SCALE/10) + COURSE_POINT_SCALE_PLUSMINUS/10
            LetterGrade("A")
        elseif  val >= 100 - 1(COURSE_POINT_SCALE/10)
            LetterGrade("A-")
        elseif  val >= 100 - 1(COURSE_POINT_SCALE/10) - COURSE_POINT_SCALE_PLUSMINUS/10
            LetterGrade("B+")
        elseif  val >= 100 - 2(COURSE_POINT_SCALE/10) + COURSE_POINT_SCALE_PLUSMINUS/10
            LetterGrade("B")
        elseif  val >= 100 - 2(COURSE_POINT_SCALE/10)
            LetterGrade("B-")
        elseif  val >= 100 - 2(COURSE_POINT_SCALE/10) - COURSE_POINT_SCALE_PLUSMINUS/10
            LetterGrade("C+")
        elseif  val >= 100 - 3(COURSE_POINT_SCALE/10) + COURSE_POINT_SCALE_PLUSMINUS/10
            LetterGrade("C")
        elseif  val >= 100 - 3(COURSE_POINT_SCALE/10)
            LetterGrade("C-")
        elseif  val >= 100 - 3(COURSE_POINT_SCALE/10) - COURSE_POINT_SCALE_PLUSMINUS/10
            LetterGrade("D+")
        elseif  val >= 100 - 4(COURSE_POINT_SCALE/10) + COURSE_POINT_SCALE_PLUSMINUS/10
            LetterGrade("D")
        elseif  val >= 100 - 4(COURSE_POINT_SCALE/10)
            LetterGrade("D-")
        elseif  val >= 0
            LetterGrade("F")
        else
            LetterGrade("FN")
        end
    end
end
credit2letter(p::T, v::T) where {T<:Point} = credit2letter(p / v)
credit2letter(p::T, v::T) where {T<:Real} = credit2letter(Point(p) / Point(v))

"Calculates quality point weight of `LetterGrade` according to preferences `COURSE_QUALITYPOINTS_A`, `COURSE_QUALITYPOINTS_PLUSMINUS`, and `COURSE_QUALITYPOINTS_APLUS`."
function quality_points(g::LetterGrade)
    return if   g.level == F || g.level == FN
        0
    elseif      g.level == I || g.level == W
        NaN
    elseif COURSE_QUALITYPOINTS_PLUSMINUS == 0
        if      g.level == A
            COURSE_QUALITYPOINTS_A - 0
        elseif  g.level == B
            COURSE_QUALITYPOINTS_A - 1
        elseif  g.level == C
            COURSE_QUALITYPOINTS_A - 2
        elseif  g.level == D
            COURSE_QUALITYPOINTS_A - 3
        end
    else
        if      g.level == A_plus
            COURSE_QUALITYPOINTS_APLUS
        elseif  g.level == A
            COURSE_QUALITYPOINTS_A
        elseif  g.level == A
            COURSE_QUALITYPOINTS_A - 0 - COURSE_QUALITYPOINTS_PLUSMINUS
        elseif  g.level == B_plus
            COURSE_QUALITYPOINTS_A - 1 + COURSE_QUALITYPOINTS_PLUSMINUS
        elseif  g.level == B
            COURSE_QUALITYPOINTS_A - 1
        elseif  g.level == B_minus
            COURSE_QUALITYPOINTS_A - 1 - COURSE_QUALITYPOINTS_PLUSMINUS
        elseif  g.level == C_plus
            COURSE_QUALITYPOINTS_A - 2 + COURSE_QUALITYPOINTS_PLUSMINUS
        elseif  g.level == C
            COURSE_QUALITYPOINTS_A - 2
        elseif  g.level == C_minus
            COURSE_QUALITYPOINTS_A - 2 - COURSE_QUALITYPOINTS_PLUSMINUS
        elseif  g.level == D_plus
            COURSE_QUALITYPOINTS_A - 3 + COURSE_QUALITYPOINTS_PLUSMINUS
        elseif  g.level == D
            COURSE_QUALITYPOINTS_A - 3
        elseif  g.level == D_minus
            COURSE_QUALITYPOINTS_A - 3 - COURSE_QUALITYPOINTS_PLUSMINUS
        end
    end
end

"Calculates weighted GPA from `quality_points` of `LetterGrade` and course `credit`s (defaults to preference `COURSE_CREDITS`)."
gpa(g::LetterGrade, credit::Integer=COURSE_CREDITS) = quality_points(g) * credit
