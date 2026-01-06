module Gradebooks

using CSV
using DataFrames
using Dates
using Distributed
using Glob
using JSON
using OteraEngine
using Preferences
using PrettyTables
using Printf
using RecipesBase
# using Plots; gr()

# default(
#     fontfamily="Computer Modern",
#     linewidth=1,
#     framestyle=:box,
#     label=nothing,
#     grid=false)
# scalefontsizes(1.3)

const ORG_IDPREFIX = @load_preference("ORG_IDPREFIX")
const ORG_EMAILDOMAIN = @load_preference("ORG_EMAILDOMAIN")

function set_orgidprefix(prefix::String)
    @set_preferences!("ORG_IDPREFIX" => prefix)
    @info("New `ORG_IDPREFIX` set; restart your Julia session for this change to take effect!")
end

get_orgidprefix() = @load_preference("ORG_IDPREFIX")

function set_orgemaildomain(domain::String)
    @set_preferences!("ORG_EMAILDOMAIN" => domain)
    @info("New `ORG_EMAILDOMAIN` set; restart your Julia session for this change to take effect!")
end

set_orgemaildomain() = @load_preference("ORG_EMAILDOMAIN")

const MIDNIGHT = Time(23, 59, 59, 999)

function datetime(d)
    if isa(d, DateTime)
        return d
    elseif isa(d, Date)
        d = if year(d) == 1
            Date(year(now()), month(d), day(d))
        else
            d
        end
        return DateTime(d, MIDNIGHT)
    elseif isa(d, String)
        try
            return DateTime(d, ISODateTimeFormat)
        catch
            try
                return DateTime(Date(DateTime(d, ISODateFormat)), MIDNIGHT)
            catch
                try
                    function parse_datetime(df)
                        return try
                            DateTime(d, df)
                        catch exc
                            if isa(exc, ArgumentError)
                                nothing
                            else
                                @error "Could not parse..."
                            end
                        end
                    end
                    date_variations = ["y-m-d", "m-d", "yyyymmdd", "m/d/y", "m/d", "U d, y", "U d", "u. d, y", "u. d", "u d, y", "u d"]
                    time_variations = ["H:M:S.s", "H:M", "HHMM", "I:M p", "I:MMp", "IIMM p", "IIMMp"]
                    datetimeformats = DateFormat.(vcat(
                        vcat(vcat(map(delim->map(ds->map(ts->join([ds, ts], delim), time_variations), date_variations[1:3]), ["T", " ", ""])...)...),
                        vcat(vcat(map(delim->map(ds->map(ts->join([ds, ts], delim), time_variations), date_variations[4:end]), [" "])...)...),
                    ))
                    i, parse, n = 0, nothing, length(datetimeformats)
                    while isnothing(parse)
                        i += 1
                        if i == n + 1
                            @error "Could not parse..."
                        end
                        parse = parse_datetime(datetimeformats[i])
                    end
                    d = parse
                    d = if Dates.value(Time(d)) == 0
                        DateTime(d, MIDNIGHT)
                    else
                        d
                    end
                    return if year(d) == 1
                        DateTime(Date(year(now()), month(d), day(d)), Time(d))
                    else
                        d
                    end
                catch
                    @error "I could not parse the datetime..." d
                end
            end
        end
    else
        @info "Must be `DateTime` or `String` but is" typeof(d)
        @error "I could not parse the datetime..." d
    end
end

abstract type AbstractPerson end

name(firstname, lastname; title="", suffix="", nickname="") = join(filter(!isnothing, [(isempty(title) ? nothing : (title=strip(title); last(title) == '.' ? title : "$title.")), firstname, (isempty(nickname) ? nothing : "\"$nickname\""), lastname]), " ") * (suffix == "" ? "" : (first(suffix) == ',' ? suffix : ", $suffix"))
codename(firstname, lastname; nickname="") = uppercase(join(map(s->first(s, 1), [!isempty(nickname) ? nickname : firstname, lastname])))

struct Instructor <: AbstractPerson
    firstname
    lastname
    title
    suffix
    nickname
    initials
    email
    phone
    organization
    job_title
    id
    name
    codename
    function Instructor(firstname, lastname; title="", suffix="", nickname="", initials="", email="", phone="", organization="", job_title="", id="")
        name = name(firstname, lastname; title=title, suffix=suffix, nickname=nickname)
        codename = !isempty(initials) ? initials : codename(firstname, lastname; nickname=nickname)
        return new(firstname, lastname, title, suffix, nickname, codename, email, phone, organization, job_title, id, name, codename)
    end
end

struct Student <: AbstractPerson
    firstname
    lastname
    title
    suffix
    nickname
    initials
    email
    phone
    organization
    discipline
    id
    name
    codename
    function Student(firstname, lastname; title="", suffix="", nickname="", initials="", email="", phone="", organization="", discipline="", id="")
        name = name(firstname, lastname; title=title, suffix=suffix, nickname=nickname)
        codename = !isempty(initials) ? initials : codename(firstname, lastname; nickname=nickname)
        return new(firstname, lastname, title, suffix, nickname, codename, email, phone, organization, discipline, id, name, codename)
    end
end

struct Course
    code
    number
    name
    codename
    Course(code, number, name) = new(code, number, name, uppercase("$code$number"))
end

struct Class
    course::Course
    section
    semester
    year
    codename_short
    codename_long
    instructor::Instructor
    students::Vector{Student}
    roster::Vector{Student}
    function Class(course::Course, section, semester, year, instructor::Instructor, students::Vector{Student})
        section_padded = @sprintf("%03d", section)
        return new(
            course, section, uppercasefirst(lowercase(semester)), year,
            course.codename, join(["$(course.codename)", "$section_padded", first(uppercase(semester)) * (uppercase(semester)[1:2] == "SU" ? "u" : "") * last("$year", 2)], "-"),
            instructor, students, students
        )
    end
end

abstract type AbstractAssignment end
abstract type AbstractAssignmentType end
struct Group <: AbstractAssignmentType end
struct Individual <: AbstractAssignmentType end
abstract type AbstractHomework{T<:AbstractAssignmentType} <: AbstractAssignment end
abstract type AbstractExam{T<:AbstractAssignmentType} <: AbstractAssignment end
abstract type AbstractPaper{T<:AbstractAssignmentType} <: AbstractAssignment end
abstract type AbstractPresentation{T<:AbstractAssignmentType} <: AbstractAssignment end
abstract type AbstractProject{T<:AbstractAssignmentType} <: AbstractAssignment end
const AbstractQuiz = AbstractExam
abstract type AbstrasctAttendance <: AbstractAssignment end
abstract type AbstractAssignmentValueType end
abstract type Points <: AbstractAssignmentValueType end
abstract type Percentage <: AbstractAssignmentValueType end

struct Assignment{T<:AbstractAssignment}
    name::String
    value::UInt64
    due_datetime::DateTime
    class::Class
    Assignment{T}(name, value, due_date, class) where {T<:AbstractAssignment} = new{T}(name, value, fetch_datetime(due_date), class)
end
# Attendance()
Homework(T, name, value, due_date, class) = Assignment{AbstractHomework{T}}(name, value, due_date, class)
Exam(T, name, value, due_date, class) = Assignment{AbstractExam{T}}(name, value, due_date, class)
Paper(T, name, value, due_date, class) = Assignment{AbstractPaper{T}}(name, value, due_date, class)
Presentation(T, name, value, due_date, class) = Assignment{AbstractPresentation{T}}(name, value, due_date, class)
Project(T, name, value, due_date, class) = Assignment{AbstractProject{T}}(name, value, due_date, class)
Quiz(T, name, value, due_date, class) = Assignment{AbstractQuiz{T}}(name, value, due_date, class)

function fetch_lettergrade(p)
    return if p >= 90
        'A'
    elseif p >= 80
        'B'
    elseif p >= 70
        'C'
    elseif p >= 60
        'D'
    else
        'F'
    end
end

fetch_lettergrade(s, v) = fetch_lettergrade(100(s / v))

struct Submission{T<:Assignment}
    assignment::T
    submission_datetime::DateTime
    score_points::AbstractFloat
    score_percentage::AbstractFloat
    score_letter::String
    function Submission{T}(assignment, submission_datetime, score) where {T<:Assignment}
        score_percentage = 100(score / assignment.value)
        score_letter = fetch_lettergrade(score_percentage)
        return new{T}(assignment, submission_datetime, score, score_percentage, score_letter)
    end
end
# Submission{T<:Assignment{<:AbstractAssignment, Group}} = map_students_from_group;

struct Grade{T<:Submission}
    class::Class
    instructor::Instructor
    student::Student
    assignment::Assignment
    submission::T
    Grade{T}(class, instructor, student, submission) where {T<:Submission} = new{T}(class, instructor, student, submission.assignment, submission)
end

abstract type AbstractGradebook <: AbstractDataFrame end
struct Gradebook{T<:Union{Class,Student}} <: AbstractGradebook
    who::T
    assignments::Vector{Assignment}
    df::DataFrame
    Gradebook{T}(who, assignments, df) where {T<:Union{Class,Student}} = new{T}(who, assignments, df)
end
Gradebook(class::Class, assignments::Vector{Assignment}) = Gradebook{Class}(class, assignments, DataFrame(zeros((length(class.roster)+1, length(assignments)+1)), push!([a.name for a in assignments], "Final")))
const StudentGradebook = Gradebook{Student}
const ClassGradebook = Gradebook{Class}
# const Attendance{T} = Gradebook{T}
# const StudentAttendance = Attendance{Student}
# const ClassAttendance = Attendance{Class}

function _fetch_class_data(class::Class, data::String)
    data_name = join([class.codename_long, data], "-")
    data_names = filter(x->occursin(data_name, x), readdir(@__DIR__))
    data_names_strings = [split(x, "-"; limit=2)[1] for x in data_names]
    data_times_strings = [split(x, "-"; limit=2)[2] for x in data_names]
    data_times = [DateTime(x, ISODateTimeFormat) for x in data_times_strings]
    data_times_sorted = sortperm(data_times)
    data_names_strings = data_names_strings[data_times_sorted]
    data_times = data_times[data_times_sorted]
    df = CSV.read(joinpath[@__DIR__, data_names_strings[end]], DataFrame)
    return Gradebook{Class}(class, names(df), df)
end

fetch_class_gradebook(class::Class) = _fetch_class_data(class, "Gradebook")
# fetch_class_attendance(class::Class) = _fetch_class_data(class, "Attendance")

@userplot ViewGradebook
# @userplot ViewAttendance

@recipe f(::Type{Gradebook}, gb::Gradebook) = gb.df

# @filter ensure_formattedpath(p) = join(string.(split(p, r"(\\|/)+")), "/")
# @filter ensure_orgidprefix(id) = first(id) == ORG_IDPREFIX ? id : "$ORG_IDPREFIX$id"
# @filter ensure_orgemailaddress(e) = occursin("@", e) ? e : "$e$ORG_EMAILDOMAIN"
# @filter ensure_assignment_name_sanitization(n) = lowercase(replace(n, " "=>"_"))

get_reportdata(grade::T) where {T<:Grade} = ( # init
    "cwd"                       => pwd(),
    "course_code"               => grade.class.course.code,
    "course_name"               => grade.class.course.name,
    "class_semester"            => grade.class.semester,
    "class_section"             => grade.class.section,
    "class_code"                => grade.class.codename_long,
    "instructor_name_first"     => grade.instructor.firstname,
    "instructor_name_last"      => grade.instructor.lastname,
    "instructor_name"           => grade.instructor.name,
    "instructor_initials"       => grade.instructor.initials,
    "instructor_email"          => grade.instructor.email,
    "instructor_jobtitle"       => grade.instructor.job_title,
    "instructor_organization"   => grade.instructor.organization,
    "instructor_id"             => grade.instructor.id,
    "student_name_first"        => grade.student.firstname,
    "student_name_last"         => grade.student.lastname,
    "student_name"              => grade.student.name,
    "student_initials"          => grade.student.initials,
    "student_email"             => grade.student.email,
    "student_id"                => grade.student.id,
    "assignment_name"           => grade.assignment.name,
    "assignment_value"          => grade.assignment.value,
    "student_grade_points"      => grade.submission.score_points,
    "student_grade_percentage"  => grade.submission.score_percentage,
    "student_grade_letter"      => grade.submission.score_letter,
    "export_datetime"           => replace(string(now()), "-"=>"", ":"=>"", "."=>""),
)

abstract type AbstractReport end
struct DefendGrade <: AbstractReport
    template
    init
    DefendGrade() = new(Template("defense_of_grade.adoc"), Dict())
end

function DefendGrade(grade::T) where {T<:Grade}
    return new(Template("defense_of_grade.adoc"), get_reportdata(grade))
end

function write_report(report::DefendGrade, grade::T) where {T<:Grade}
    report_grade = report.template(init=get_reportdata(grade))
end

# print(report::DefendGrade) = export student view of gradebook and `print2pdf report`

end # end of module
