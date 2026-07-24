# export GradeLevel
public gradelevel2string, gradelevel2qualitypoints
export LetterGrade, Aplus, A, Aminus, Bplus, B, Bminus, Cplus, C, Cminus, Dplus, D, Dminus, F, FN, W, I
export credit2lettergrade, gpa



"Grade levels for predicate filtering and sorting."
@enum GradeLevel begin
    GradeLevel_Aplus
    GradeLevel_A
    GradeLevel_Aminus
    GradeLevel_Bplus
    GradeLevel_B
    GradeLevel_Bminus
    GradeLevel_Cplus
    GradeLevel_C
    GradeLevel_Cminus
    GradeLevel_Dplus
    GradeLevel_D
    GradeLevel_Dminus
    GradeLevel_F
    GradeLevel_FN          # failure for non-attendance
    GradeLevel_W           # withdrawn
    GradeLevel_I           # incomplete
end

"Maps grade level to string."
function gradelevel2string(lvl::GradeLevel)::String
    lvl == GradeLevel_Aplus    && return "A+"
    lvl == GradeLevel_A        && return "A"
    lvl == GradeLevel_Aminus   && return "A-"
    lvl == GradeLevel_Bplus    && return "B+"
    lvl == GradeLevel_B        && return "B"
    lvl == GradeLevel_Bminus   && return "B-"
    lvl == GradeLevel_Cplus    && return "C+"
    lvl == GradeLevel_C        && return "C"
    lvl == GradeLevel_Cminus   && return "C-"
    lvl == GradeLevel_Dplus    && return "D+"
    lvl == GradeLevel_D        && return "D"
    lvl == GradeLevel_Dminus   && return "D-"
    lvl == GradeLevel_F        && return "F"
    lvl == GradeLevel_FN       && return "FN"
    lvl == GradeLevel_W        && return "W"
    lvl == GradeLevel_I        && return "I"
    @warn "Must be" GradeLevel
    error("Input not recognized: g=$lvl")
end

"Calculates quality point weight of `LetterGrade` according to preferences `COURSE_QUALITYPOINTS_A`, `COURSE_QUALITYPOINTS_PLUSMINUS`, and `COURSE_QUALITYPOINTS_APLUS`."
function gradelevel2qualitypoints(lvl::GradeLevel)
    return if   lvl == GradeLevel_F || lvl == GradeLevel_FN
        0
    elseif      lvl == GradeLevel_I || lvl == GradeLevel_W
        NaN
    elseif COURSE_QUALITYPOINTS_PLUSMINUS == 0
        if      lvl ∈ (GradeLevel_Aplus, GradeLevel_A, GradeLevel_Aminus)
            COURSE_QUALITYPOINTS_A - 0
        elseif  lvl ∈ (GradeLevel_Bplus, GradeLevel_B, GradeLevel_Bminus)
            COURSE_QUALITYPOINTS_A - 1
        elseif  lvl ∈ (GradeLevel_Cplus, GradeLevel_C, GradeLevel_Cminus)
            COURSE_QUALITYPOINTS_A - 2
        elseif  lvl ∈ (GradeLevel_Dplus, GradeLevel_D, GradeLevel_Dminus)
            COURSE_QUALITYPOINTS_A - 3
        else
            throw(ArgumentError("Unsupported grade level: $lvl"))
        end
    else
        if      lvl == GradeLevel_Aplus
            COURSE_QUALITYPOINTS_APLUS
        elseif  lvl == GradeLevel_A
            COURSE_QUALITYPOINTS_A
        elseif  lvl == GradeLevel_Aminus
            COURSE_QUALITYPOINTS_A - 0 - COURSE_QUALITYPOINTS_PLUSMINUS
        elseif  lvl == GradeLevel_Bplus
            COURSE_QUALITYPOINTS_A - 1 + COURSE_QUALITYPOINTS_PLUSMINUS
        elseif  lvl == GradeLevel_B
            COURSE_QUALITYPOINTS_A - 1
        elseif  lvl == GradeLevel_Bminus
            COURSE_QUALITYPOINTS_A - 1 - COURSE_QUALITYPOINTS_PLUSMINUS
        elseif  lvl == GradeLevel_Cplus
            COURSE_QUALITYPOINTS_A - 2 + COURSE_QUALITYPOINTS_PLUSMINUS
        elseif  lvl == GradeLevel_C
            COURSE_QUALITYPOINTS_A - 2
        elseif  lvl == GradeLevel_Cminus
            COURSE_QUALITYPOINTS_A - 2 - COURSE_QUALITYPOINTS_PLUSMINUS
        elseif  lvl == GradeLevel_Dplus
            COURSE_QUALITYPOINTS_A - 3 + COURSE_QUALITYPOINTS_PLUSMINUS
        elseif  lvl == GradeLevel_D
            COURSE_QUALITYPOINTS_A - 3
        elseif  lvl == GradeLevel_Dminus
            COURSE_QUALITYPOINTS_A - 3 - COURSE_QUALITYPOINTS_PLUSMINUS
        else
            throw(ArgumentError("Unsupported grade level: $lvl"))
        end
    end
end


"Letter grade (e.g., A or B+) earned for course item."
struct LetterGrade
    level::GradeLevel
end

function Base.getproperty(letter::LetterGrade, sym::Symbol)
    if sym == :string
        return gradelevel2string(getfield(letter, :level))
    elseif sym == :quality_points
        return gradelevel2qualitypoints(getfield(letter, :level))
    else
        return getfield(letter, sym)
    end
end

Base.propertynames(ℓ::LetterGrade) = (:level, :string, :quality_points)

const Aplus     = LetterGrade(GradeLevel_Aplus)
const A         = LetterGrade(GradeLevel_A)
const Aminus    = LetterGrade(GradeLevel_Aminus)
const Bplus     = LetterGrade(GradeLevel_Bplus)
const B         = LetterGrade(GradeLevel_B)
const Bminus    = LetterGrade(GradeLevel_Bminus)
const Cplus     = LetterGrade(GradeLevel_Cplus)
const C         = LetterGrade(GradeLevel_C)
const Cminus    = LetterGrade(GradeLevel_Cminus)
const Dplus     = LetterGrade(GradeLevel_Dplus)
const D         = LetterGrade(GradeLevel_D)
const Dminus    = LetterGrade(GradeLevel_Dminus)
const F         = LetterGrade(GradeLevel_F)
const FN        = LetterGrade(GradeLevel_FN)
const W         = LetterGrade(GradeLevel_W)
const I         = LetterGrade(GradeLevel_I)


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
