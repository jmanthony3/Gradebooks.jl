export generate_report, generate_report_academic_misconduct, generate_report_grade_defense, generate_report_late_penalty_appeal



using OteraEngine, Dates



# @filter ensure_formattedpath(p) = join(string.(split(p, r"(\\|/)+")), "/")
# @filter ensure_orgidprefix(id) = first(id) == ORG_IDPREFIX ? id : "$ORG_IDPREFIX$id"
# @filter ensure_orgemailaddress(e) = occursin("@", e) ? e : "$e$organization_EMAILDOMAIN"
# @filter ensure_assignment_name_sanitization(n) = lowercase(replace(n, " "=>"_"))


const TEMPLATE_DIR = joinpath(@__DIR__, "..", "templates")

@enum ReportType AcademicMisconduct GradeDefense LatePenalty


function student_context(gb::Gradebook, student::Student)
    return Dict(
        "student_name_given" => student.person.name_given,
        "student_name_preferred" => student.person.name_preferred,
        "student_name_family" => student.person.name_family,
        "student_name" => student.person.name,
        "student_name_initials" => student.person.name_initials,
        "student_id" => student.id,
        "student_email" => student.email,
        "course_code" => gb.class.course.code,
        "course_name" => gb.class.course.name,
        "class_section" => gb.class.section,
        "class_semester" => gb.class.semester,
        "class_codename" => gb.class.codename_short,
        "instructor_name" => gb.class.instructor.person.name,
        "instructor_name_initials" => gb.class.instructor.person.name_initials,
        "instructor_job_title" => gb.class.instructor.job_title,
        "instructor_email" => gb.class.instructor.person.email,
    ), now()
end

function assignment_context(gb::Gradebook, student::Student, assignment::Assignment, t::DateTime)
    # replace this with your real lookup helper
    grade = gb.total[occursin.(student, gb.class.roster.students), assignment.codename]
    score = grade.submission.score

    path = joinpath(
            pwd(), "reports",
            lowercase(student.person.name_family) * "_" * lowercase(student.person.name_given) *
                "-" * assignment.codename * "+" * safe_datetime_stamp(t) * ".html"
        )
    view_assignment(gb, assignment; student_filter=findall(s->s==student, gb.class.roster.students), output_path=path)

    return Dict(
        "assignment_name" => assignment.name,
        "assignment_value" => assignment.value,
        "assignment_codename" => assignment.codename,
        "student_grade_earned" => score.earned,
        "student_grade_percent" => score.percent,
        "student_grade_earned" => score.letter,
        "gradebook_path" => path,
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
    ctx, t = student_context(gb, student)

    # always include these common keys
    ctx["report_type"] = report_type
    ctx["report_date"] = Date(t)
    ctx["report_time"] = Time(t)
    ctx["notes"] = notes

    # safe defaults
    ctx["assignments"] = [
        assignment_context(gb, student, a, t) for a in assignments
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


function render_template(template_name::AbstractString, context::Dict; output_path=joinpath(pwd(), "reports"))
    template = OteraEngine.Template(joinpath(TEMPLATE_DIR, template_name))
    rendered = template(context)
    mkpath(dirname(output_path))
    write(output_path, rendered)
    return rendered
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
        error("Got unsupported type: $report_type")
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

generate_report_academic_misconduct(gb, student; kwargs...) = generate_report(gb, student, AcademicMisconduct; kwargs...)
generate_report_grade_defense(gb, student; kwargs...)       = generate_report(gb, student, GradeDefense; kwargs...)
generate_report_late_penalty_appeal(gb, student; kwargs...) = generate_report(gb, student, LatePenalty; kwargs...)
