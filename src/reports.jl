export get_reportdata
export AbstractReport, DefendGrade, write_report

using OteraEngine, Dates

# @filter ensure_formattedpath(p) = join(string.(split(p, r"(\\|/)+")), "/")
# @filter ensure_orgidprefix(id) = first(id) == ORG_IDPREFIX ? id : "$ORG_IDPREFIX$id"
# @filter ensure_orgemailaddress(e) = occursin("@", e) ? e : "$e$organization_EMAILDOMAIN"
# @filter ensure_assignment_name_sanitization(n) = lowercase(replace(n, " "=>"_"))

const TEMPLATE_DIR = joinpath(@__DIR__, "..", "templates")

@enum ReportType AcademicMisconduct GradeDefense LatePenalty

function render_template(template_name::AbstractString, context::Dict; output_path=nothing)
    template = OteraEngine.Template(joinpath(TEMPLATE_DIR, template_name))
    rendered = template(context)
    if output_path !== nothing
        mkpath(dirname(output_path))
        write(output_path, rendered)
    end
    return rendered
end

function student_context(gb::Gradebook, student::Student)
    return Dict(
        "student_id" => student.id,
        "student_email" => student.email,
        "student_name" => student.person.name,
        "student_name_first" => student.person.name_given,
        "student_name_last" => student.person.name_family,
        "student_name_preferred" => student.person.name_preferred,
        "course_code" => gb.class.course.code,
        "course_name" => gb.class.course.name,
        "section" => gb.class.section,
        "semester" => gb.class.semester,
        "instructor_name" => gb.class.instructor.person.name,
        "instructor_email" => gb.class.instructor.email,
        "report_date" => Dates.today()
    )
end

function assignment_context(gb::Gradebook, student::Student, assignment::Assignment)
    # replace this with your real lookup helper
    grade = get_grade(gb, student, assignment)
    score = grade.submission.score

    return Dict(
        "assignment_name" => assignment.name,
        "assignment_codename" => assignment.codename,
        "assignment_value" => assignment.value,
        "score_points" => score.score,
        "score_percent" => score.percent,
        "score_letter" => score.letter,
        "comments" => [e.comment for e in grade.submission.evaluations if !isempty(e.comment)]
    )
end

function evidence_context(evidence)
    if evidence isa AbstractString
        return Dict(
            "path" => evidence,
            "name" => basename(evidence),
            "size" => filesize(evidence),
            "kind" => splitext(evidence)[2]
        )
    else
        return Dict(
            "path" => "",
            "name" => string(evidence),
            "size" => missing,
            "kind" => ""
        )
    end
end

function report_context(
    gb::Gradebook,
    student::Student;
    report_type::Union{Nothing, ReportType}=nothing,
    assignments::Vector{Assignment}=Assignment[],
    evidence=Any[],
    notes::AbstractString="",
    extra_fields::Dict=Dict()
)
    ctx = student_context(gb, student)

    # always include these common keys
    ctx["report_type"] = report_type
    ctx["report_date"] = Dates.today()
    ctx["notes"] = notes

    # safe defaults
    ctx["assignments"] = [
        assignment_context(gb, student, a) for a in assignments
    ]

    ctx["evidence"] = [
        evidence_context(e) for e in evidence
    ]

    # report-type-specific keys
    for (k, v) in extra_fields
        ctx[string(k)] = v
    end

    return ctx
end

function generate_report(
    gb::Gradebook,
    student::Student,
    report_type::ReportType;
    assignments::Vector{Assignment}=Assignment[],
    evidence=Any[],
    notes::AbstractString="",
    extra_fields::Dict=Dict(),
    output_path=nothing
)
    template_name = if report_type == AcademicMisconduct
        "$TEMPLATE_DIR/academic_misconduct.adoc"
    elseif report_type == GradeDefense
        "$TEMPLATE_DIR/defense_of_grade.adoc"
    elseif report_type == LatePenalty
        "$TEMPLATE_DIR/late_penalty.adoc"
    else
        @error "Report type not understood." type=report_type
    end

    ctx = report_context(
        gb, student;
        report_type=report_type,
        assignments=assignments,
        evidence=evidence,
        notes=notes,
        extra_fields=extra_fields
    )

    return render_template(template_name, ctx; output_path=output_path)
end

generate_academic_misconduct(gb, student; kwargs...) =
    generate_report(gb, student, AcademicMisconduct; kwargs...)

generate_grade_defense(gb, student; kwargs...) =
    generate_report(gb, student, GradeDefense; kwargs...)

generate_late_penalty_appeal(gb, student; kwargs...) =
    generate_report(gb, student, LatePenalty; kwargs...)
