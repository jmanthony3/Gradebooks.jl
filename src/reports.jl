export get_reportdata
export AbstractReport, DefendGrade, write_report

using OteraEngine

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
    "export_datetime"           => safe_datetime_stamp(),
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
