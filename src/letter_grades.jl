export GradeLevel, determine_level, quality_points
export LetterGrade, Aplus, A, Aminus, Bplus, B, Bminus, Cplus, C, Cminus, Dplus, D, Dminus, F, FN, W, I
export credit2lettergrade, gpa



"Grade levels for predicate filtering and sorting."
@enum GradeLevel begin
    GradeAplus
    GradeA
    GradeAminus
    GradeBplus
    GradeB
    GradeBminus
    GradeCplus
    GradeC
    GradeCminus
    GradeDplus
    GradeD
    GradeDminus
    GradeF
    GradeFN          # Failure for Non-attendance
    GradeW           # Withdrawn
    GradeI           # Incomplete
end

"Maps string to grade level."
function determine_level(g::GradeLevel)::String
    g == GradeAplus    && return "A+"
    g == GradeA        && return "A"
    g == GradeAminus   && return "A-"
    g == GradeBplus    && return "B+"
    g == GradeB        && return "B"
    g == GradeBminus   && return "B-"
    g == GradeCplus    && return "C+"
    g == GradeC        && return "C"
    g == GradeCminus   && return "C-"
    g == GradeDplus    && return "D+"
    g == GradeD        && return "D"
    g == GradeDminus   && return "D-"
    g == GradeF        && return "F"
    g == GradeFN       && return "FN"
    g == GradeW        && return "W"
    g == GradeI        && return "I"
    @warn "Must be" GradeLevel
    error("Input not recognized: g=$g")
end

"Calculates quality point weight of `LetterGrade` according to preferences `COURSE_QUALITYPOINTS_A`, `COURSE_QUALITYPOINTS_PLUSMINUS`, and `COURSE_QUALITYPOINTS_APLUS`."
function quality_points(lvl::GradeLevel)
    return if   lvl == GradeF || lvl == GradeFN
        0
    elseif      lvl == GradeI || lvl == GradeW
        NaN
    elseif COURSE_QUALITYPOINTS_PLUSMINUS == 0
        if      lvl ∈ (GradeAplus, GradeA, GradeAminus)
            COURSE_QUALITYPOINTS_A - 0
        elseif  lvl ∈ (GradeBplus, GradeB, GradeBminus)
            COURSE_QUALITYPOINTS_A - 1
        elseif  lvl ∈ (GradeCplus, GradeC, GradeCminus)
            COURSE_QUALITYPOINTS_A - 2
        elseif  lvl ∈ (GradeDplus, GradeD, GradeDminus)
            COURSE_QUALITYPOINTS_A - 3
        else
            throw(ArgumentError("Unsupported grade level: $lvl"))
        end
    else
        if      lvl == GradeAplus
            COURSE_QUALITYPOINTS_APLUS
        elseif  lvl == GradeA
            COURSE_QUALITYPOINTS_A
        elseif  lvl == GradeAminus
            COURSE_QUALITYPOINTS_A - 0 - COURSE_QUALITYPOINTS_PLUSMINUS
        elseif  lvl == GradeBplus
            COURSE_QUALITYPOINTS_A - 1 + COURSE_QUALITYPOINTS_PLUSMINUS
        elseif  lvl == GradeB
            COURSE_QUALITYPOINTS_A - 1
        elseif  lvl == GradeBminus
            COURSE_QUALITYPOINTS_A - 1 - COURSE_QUALITYPOINTS_PLUSMINUS
        elseif  lvl == GradeCplus
            COURSE_QUALITYPOINTS_A - 2 + COURSE_QUALITYPOINTS_PLUSMINUS
        elseif  lvl == GradeC
            COURSE_QUALITYPOINTS_A - 2
        elseif  lvl == GradeCminus
            COURSE_QUALITYPOINTS_A - 2 - COURSE_QUALITYPOINTS_PLUSMINUS
        elseif  lvl == GradeDplus
            COURSE_QUALITYPOINTS_A - 3 + COURSE_QUALITYPOINTS_PLUSMINUS
        elseif  lvl == GradeD
            COURSE_QUALITYPOINTS_A - 3
        elseif  lvl == GradeDminus
            COURSE_QUALITYPOINTS_A - 3 - COURSE_QUALITYPOINTS_PLUSMINUS
        else
            throw(ArgumentError("Unsupported grade level: $lvl"))
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
LetterGrade(g::GradeLevel) = LetterGrade(g, determine_level(g), quality_points(g))

const Aplus     = LetterGrade(GradeAplus)
const A         = LetterGrade(GradeA)
const Aminus    = LetterGrade(GradeAminus)
const Bplus     = LetterGrade(GradeBplus)
const B         = LetterGrade(GradeB)
const Bminus    = LetterGrade(GradeBminus)
const Cplus     = LetterGrade(GradeCplus)
const C         = LetterGrade(GradeC)
const Cminus    = LetterGrade(GradeCminus)
const Dplus     = LetterGrade(GradeDplus)
const D         = LetterGrade(GradeD)
const Dminus    = LetterGrade(GradeDminus)
const F         = LetterGrade(GradeF)
const FN        = LetterGrade(GradeFN)
const W         = LetterGrade(GradeW)
const I         = LetterGrade(GradeI)


"Converts `Credit` to `LetterGrade` according to preferences `COURSE_POINT_SCALE` and `COURSE_POINT_SCALE_PLUSMINUS`."
function credit2lettergrade(p::Percent)::LetterGrade
    val = p.value * 100
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
