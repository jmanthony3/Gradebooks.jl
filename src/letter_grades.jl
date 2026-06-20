export GradeLevel, determine_level, quality_points
export LetterGrade, Aplus, A, Aminus, Bplus, B, Bminus, Cplus, C, Cminus, Dplus, D, Dminus, F, FN, W, I
export credit2lettergrade, gpa



"Grade levels for predicate filtering and sorting."
@enum GradeLevel begin
    Grade_Aplus
    Grade_A
    Grade_Aminus
    Grade_Bplus
    Grade_B
    Grade_Bminus
    Grade_Cplus
    Grade_C
    Grade_Cminus
    Grade_Dplus
    Grade_D
    Grade_Dminus
    Grade_F
    Grade_FN          # Failure for Non-attendance
    Grade_W           # Withdrawn
    Grade_I           # Incomplete
end

# "Maps string to grade level."
# function determine_level(g::String)::GradeLevel
#     g = uppercase(g)
#     g == "A+"  && return Grade_Aplus
#     g == "A"   && return Grade_A
#     g == "A-"  && return Grade_Aminus
#     g == "B+"  && return Grade_Bplus
#     g == "B"   && return Grade_B
#     g == "B-"  && return Grade_Bminus
#     g == "C+"  && return Grade_Cplus
#     g == "C"   && return Grade_C
#     g == "C-"  && return Grade_Cminus
#     g == "D+"  && return Grade_Dplus
#     g == "D"   && return Grade_D
#     g == "D-"  && return Grade_Dminus
#     g == "F"   && return Grade_F
#     g == "FN"  && return Grade_FN
#     g == "W"   && return Grade_W
#     g == "I"   && return Grade_I
#     @warn "Must be A, B, C, or D (+/-) or F, FN, W, or I."
#     error("Cannot parse grade from string=$g")
# end
"Maps string to grade level."
function determine_level(g::GradeLevel)::String
    g == Grade_Aplus    && return "A+"
    g == Grade_A        && return "A"
    g == Grade_Aminus   && return "A-"
    g == Grade_Bplus    && return "B+"
    g == Grade_B        && return "B"
    g == Grade_Bminus   && return "B-"
    g == Grade_Cplus    && return "C+"
    g == Grade_C        && return "C"
    g == Grade_Cminus   && return "C-"
    g == Grade_Dplus    && return "D+"
    g == Grade_D        && return "D"
    g == Grade_Dminus   && return "D-"
    g == Grade_F        && return "F"
    g == Grade_FN       && return "FN"
    g == Grade_W        && return "W"
    g == Grade_I        && return "I"
    @warn "Must be" GradeLevel
    error("Input not recognized: g=$g")
end

"Calculates quality point weight of `LetterGrade` according to preferences `COURSE_QUALITYPOINTS_A`, `COURSE_QUALITYPOINTS_PLUSMINUS`, and `COURSE_QUALITYPOINTS_APLUS`."
function quality_points(lvl::GradeLevel)
    return if   lvl == Grade_F || lvl == Grade_FN
        0
    elseif      lvl == Grade_I || lvl == Grade_W
        NaN
    elseif COURSE_QUALITYPOINTS_PLUSMINUS == 0
        if      lvl == Grade_A
            COURSE_QUALITYPOINTS_A - 0
        elseif  lvl == Grade_B
            COURSE_QUALITYPOINTS_A - 1
        elseif  lvl == Grade_C
            COURSE_QUALITYPOINTS_A - 2
        elseif  lvl == Grade_D
            COURSE_QUALITYPOINTS_A - 3
        end
    else
        if      lvl == Grade_Aplus
            COURSE_QUALITYPOINTS_APLUS
        elseif  lvl == Grade_A
            COURSE_QUALITYPOINTS_A
        elseif  lvl == Grade_Aminus
            COURSE_QUALITYPOINTS_A - 0 - COURSE_QUALITYPOINTS_PLUSMINUS
        elseif  lvl == Grade_Bplus
            COURSE_QUALITYPOINTS_A - 1 + COURSE_QUALITYPOINTS_PLUSMINUS
        elseif  lvl == Grade_B
            COURSE_QUALITYPOINTS_A - 1
        elseif  lvl == Grade_Bminus
            COURSE_QUALITYPOINTS_A - 1 - COURSE_QUALITYPOINTS_PLUSMINUS
        elseif  lvl == Grade_Cplus
            COURSE_QUALITYPOINTS_A - 2 + COURSE_QUALITYPOINTS_PLUSMINUS
        elseif  lvl == Grade_C
            COURSE_QUALITYPOINTS_A - 2
        elseif  lvl == Grade_Cminus
            COURSE_QUALITYPOINTS_A - 2 - COURSE_QUALITYPOINTS_PLUSMINUS
        elseif  lvl == Grade_Dplus
            COURSE_QUALITYPOINTS_A - 3 + COURSE_QUALITYPOINTS_PLUSMINUS
        elseif  lvl == Grade_D
            COURSE_QUALITYPOINTS_A - 3
        elseif  lvl == Grade_Dminus
            COURSE_QUALITYPOINTS_A - 3 - COURSE_QUALITYPOINTS_PLUSMINUS
        end
    end
end

"""
    LetterGrade

A validated 1- or 2-character academic letter grade (e.g. "A", "A+", "B-", "FN", "I", "W", etc.).
Enforces length and provides nice printing/conversion.
"""
struct LetterGrade
    level::GradeLevel
    string::String
    quality_points::Real
end
# function LetterGrade(s::AbstractString)
#     s = uppercase(strip(string(s)))
#     len = length(s)
#     if len == 0 || len > 2
#         throw(ArgumentError("LetterGrade must be 1 or 2 characters, got: \"$s\"."))
#     end
#     if !all(c -> isletter(c) || c in ('+', '-'), s)
#         @warn "Unusual grade characters in \"$s\"."
#     end
#     return LetterGrade(s, determine_level(s))
# end
LetterGrade(g::GradeLevel) = LetterGrade(g, determine_level(g), quality_points(determine_level(g)))

const Aplus     = LetterGrade(Grade_Aplus)
const A         = LetterGrade(Grade_A)
const Aminus    = LetterGrade(Grade_Aminus)
const Bplus     = LetterGrade(Grade_Bplus)
const B         = LetterGrade(Grade_B)
const Bminus    = LetterGrade(Grade_Bminus)
const Cplus     = LetterGrade(Grade_Cplus)
const C         = LetterGrade(Grade_C)
const Cminus    = LetterGrade(Grade_Cminus)
const Dplus     = LetterGrade(Grade_Dplus)
const D         = LetterGrade(Grade_D)
const Dminus    = LetterGrade(Grade_Dminus)
const F         = LetterGrade(Grade_F)
const FN        = LetterGrade(Grade_FN)
const W         = LetterGrade(Grade_W)
const I         = LetterGrade(Grade_I)

"Converts `Credit` to `LetterGrade` according to preferences `COURSE_POINT_SCALE` and `COURSE_POINT_SCALE_PLUSMINUS`."
function credit2lettergrade(p::Percent)::LetterGrade
    val = p.val * 100
    return if COURSE_POINT_SCALE_PLUSMINUS == 0
        if      val >= 100 - 1(COURSE_POINT_SCALE/10)
            A
        elseif  val >= 100 - 2(COURSE_POINT_SCALE/10)
            B
        elseif  val >= 100 - 3(COURSE_POINT_SCALE/10)
            C
        elseif  val >= 100 - 4(COURSE_POINT_SCALE/10)
            D
        elseif  val >= 0
            F
        else
            FN
        end
    else
        if      val >= 100 - 0(COURSE_POINT_SCALE/10) - COURSE_POINT_SCALE_PLUSMINUS/10
            Aplus
        elseif  val >= 100 - 1(COURSE_POINT_SCALE/10) + COURSE_POINT_SCALE_PLUSMINUS/10
            A
        elseif  val >= 100 - 1(COURSE_POINT_SCALE/10)
            Aminus
        elseif  val >= 100 - 1(COURSE_POINT_SCALE/10) - COURSE_POINT_SCALE_PLUSMINUS/10
            Bplus
        elseif  val >= 100 - 2(COURSE_POINT_SCALE/10) + COURSE_POINT_SCALE_PLUSMINUS/10
            B
        elseif  val >= 100 - 2(COURSE_POINT_SCALE/10)
            Bminus
        elseif  val >= 100 - 2(COURSE_POINT_SCALE/10) - COURSE_POINT_SCALE_PLUSMINUS/10
            Cplus
        elseif  val >= 100 - 3(COURSE_POINT_SCALE/10) + COURSE_POINT_SCALE_PLUSMINUS/10
            C
        elseif  val >= 100 - 3(COURSE_POINT_SCALE/10)
            Cminus
        elseif  val >= 100 - 3(COURSE_POINT_SCALE/10) - COURSE_POINT_SCALE_PLUSMINUS/10
            Dplus
        elseif  val >= 100 - 4(COURSE_POINT_SCALE/10) + COURSE_POINT_SCALE_PLUSMINUS/10
            D
        elseif  val >= 100 - 4(COURSE_POINT_SCALE/10)
            Dminus
        elseif  val >= 0
            F
        else
            FN
        end
    end
end
credit2lettergrade(p::T, v::T) where {T<:Point} = credit2lettergrade(p / v)
credit2lettergrade(p::T, v::T) where {T<:Real} = credit2lettergrade(Point(p) / Point(v))

"Calculates weighted GPA from `quality_points` of `LetterGrade` and course `credit`s (defaults to preference `COURSE_CREDITS`)."
gpa(g::LetterGrade, credit::Integer=COURSE_CREDITS) = g.quality_points * credit
