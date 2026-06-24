export ChangeEvent, GradebookArchive
export save_gradebook, load_gradebook
export export_gradebook, import_gradebook



using CSV, DataFrames, Dates, JLD2, JSON



struct ChangeEvent
    timestamp::DateTime
    actor::String
    kind::Symbol
    target::String
    before::Any
    after::Any
end

struct GradebookArchive
    schema_version::String
    saved_at::DateTime
    gradebook::Gradebook
    history::Vector{ChangeEvent}
end


function save_archive(gb::Gradebook, path::AbstractString; history::Vector{ChangeEvent}=ChangeEvent[])
    archive = GradebookArchive(string(pkgversion(@__MODULE__)), now(), gb, history)
    mkpath(dirname(path))
    JLD2.jldsave(path; archive)
    return path
end

function load_archive(path::AbstractString)
    JLD2.jldopen(path, "r") do f
        read(f, "archive")
    end
end

"Saves gradebook (`gb`) to `path` with JLD2-serialization of `GradebookArchive`."
save_gradebook(gb::Gradebook, path::AbstractString; history::Vector{ChangeEvent}=ChangeEvent[]) = save_archive(gb, path; history=history)

"Loads JLD2-serialized archive of `GradebookArchive` and returns `gradebook` field."
load_gradebook(path::AbstractString) = ((archive = load_archive(path)); archive.gradebook)


# --- JSON export helpers -----------------------------------------------------


function flatten_question(q)
    return Dict(
        "name" => q.name,
        "value" => q.value,
        "parts" => isnothing(q.parts) ? q.parts : flatten_question.(q.parts),
        "codename" => q.codename
    )
end

function flatten_assignment(a)
    return Dict(
        "name" => a.name,
        "value" => a.value,
        "due" => a.due,
        "category" => a.category,
        "is_group" => a.is_group,
        "questions" => flatten_question.(a.questions),
        "codename" => a.codename
    )
end

function flatten_course(c)
    return Dict(
        "code" => c.code,
        "number" => c.number,
        "name" => c.name,
        "credits" => c.credits,
        "assignments" => flatten_assignment(c.assignments),
        "codename" => c.codename
    )
end

function flatten_term(c)
    return Dict(
        "name" => c.name,
        "calendar_type" => c.calendar_type,
        "year" => c.year,
        "start" => c.start,
        "finish" => c.finish,
        "holidays" => c.holidays,
        "code" => c.code,
        "metadata" => c.metadata
    )
end

function flatten_person(p)
    return Dict(
        "name_given" => p.name_given,
        "name_family" => p.name_family,
        "name_title" => p.name_title,
        "name_suffix" => p.name_suffix,
        "name_preferred" => p.name_preferred,
        "name_initials" => p.name_initials,
        "name_aliases" => p.name_aliases,
        "email" => p.email,
        "phone" => p.phone,
        "organization" => p.organization,
        "id" => p.id,
        "name" => p.name,
        "codename" => p.codename
    )
end

function flatten_instructor(s)
    return Dict(
        "person" => flatten_person(s.person),
        "job_title" => s.job_title,
        "notes" => flatten_dict(s.notes)
    )
end

function flatten_lettergrade(lg)
    return Dict(
        "level" => lg.level,
        "string" => lg.string,
        "quality_points" => lg.quality_points
    )
end

function flatten_student(s)
    return Dict(
        "person" => flatten_person(s.person),
        "discipline" => s.discipline,
        "enrollment_status" => string(s.enrollment_status),
        "final_grade" => isnothing(s.final_grade) ? nothing : flatten_lettergrade(s.final_grade),
        "withdrawal_date" => s.withdrawal_date,
        "notes" => flatten_dict(s.notes)
    )
end

function flatten_class(c)
    return Dict(
        "course" => flatten_course(c.course),
        "term" => flatten_term(c.term),
        "section" => c.section,
        "frequency" => c.frequency,
        "time_start" => c.time_start,
        "time_finish" => c.time_finish,
        "time_duration" => c.time_duration,
        "lectures" => flatten_assignment(c.lectures),
        "codename_short" => c.codename_short,
        "codename_long" => c.codename_long,
        "primary_instructor" => flatten_instructor(c.primary_instructor),
        "instructors" => flatten_instructor.(c.instructors),
        "roster" => flatten_student.(c.roster.students)
    )
end

function flatten_score(s)
    return Dict(
        "earned" => s.earned,
        "value" => s.value,
        "percent" => s.percent,
        "letter" => flatten_lettergrade(s.letter),
        "comment" => s.comment
    )
end

function flatten_mark(m)
    return Dict(
        "delta" => m.delta,
        "delta_type" => typeof(m.delta),
        "comment" => m.comment
    )
end

function flatten_evaluation(e)
    return Dict(
        "target" => flatten_question(e.target),
        "mark" => flatten_mark(e.mark),
        "comment" => e.comment
    )
end

function flatten_submission(g)
    return Dict(
        "submitted" => g.submitted,
        "score" => flatten_score(g.score),
        "evaluations" => flatten_evaluation.(g.evaluations)
    )
end

function flatten_grade(g)
    return Dict(
        "student" => flatten_student(g.student),
        "assignment" => flatten_assignment(g.assignment),
        "submission" => flatten_submission(g.submission)
    )
end

function flatten_gradebook(gb::Gradebook)
    return Dict(
        "schema_version" => string(pkgversion(@__MODULE__)),
        "saved_at" => string(now()),
        "class" => flatten_class(gb.class),
        "grades" => flatten_grade.(gb.grades),
        "raw" => gb.raw,
        "penalty" => gb.penalty,
        "total" => gb.total
    )
end

"Exports gradebook (`gb`) to `path` in `format`: `:json` or `:csv`."
function export_gradebook(gb::Gradebook, path::AbstractString; format::Union{Nothing, Symbol}=nothing)
    if lowercase(splitext(path)[2]) == ".json" || format == :json
        data = flatten_gradebook(gb)
        mkpath(dirname(path))
        open(path, "w") do io
            JSON.print(io, data, 2)
        end
        return path
    elseif lowercase(splitext(path)[2]) == ".csv" || format == :csv
        mkpath(dirname(path))
        CSV.write(path, gb.total)
        return path
    else
        error("Unsupported export format: $format")
    end
end


# --- JSON archive round-trip -------------------------------------------------


function rebuild_course_from_dict(d)
    # Replace with your real constructor
    return Course(
        d["name"],
        d["code"],
        d["semester"],
        d["section"]
    )
end

function rebuild_student_from_dict(d)
    # Replace with your real constructor
    person = Person(
        d["name_given"],
        d["name_family"],
        d["name_preferred"]
    )

    return Student(
        id=d["id"],
        email=d["email"],
        person=person,
        enrollment_status=Symbol(d["enrollment_status"]),
        final_grade = d["final_grade"] === nothing ? nothing : LetterGrade(d["final_grade"])
    )
end

function rebuild_roster_from_dict(d, students_by_id)
    # Replace with your real constructor
    students = [students_by_id[x] for x in d["student_ids"]]
    return Roster(students)
end

function rebuild_class_from_dict(d, course, roster)
    # Replace with your real constructor
    return Class(course, roster)
end

function rebuild_item_from_dict(d)
    # This recursively rebuilds any question/rubric tree.
    # If your item types differ, update the constructor calls below.
    if haskey(d, "parts") && !isempty(d["parts"])
        parts = [rebuild_item_from_dict(p) for p in d["parts"]]
        return Question(
            d["codename"],
            d["label"],
            d["value"],
            parts
        )
    else
        return Question(
            d["codename"],
            d["label"],
            d["value"]
        )
    end
end

function rebuild_assignment_from_dict(d)
    questions = [rebuild_item_from_dict(q) for q in d["questions"]]
    return Assignment(
        d["codename"],
        d["name"],
        d["value"],
        questions
    )
end

function parse_json_mark(d)
    kind = get(d, "kind", "Point")
    value = get(d, "value", 0)

    if kind == "Point"
        return Point(value)
    elseif kind == "Percent"
        return Percent(value)
    else
        error("Unsupported JSON mark kind: $kind")
    end
end

function rebuild_evaluation_from_dict(d)
    return Evaluation(
        d["item"],
        parse_json_mark(d["mark"]),
        d["comment"]
    )
end

function rebuild_submission_from_dict(d, students_by_id, assignments_by_codename)
    student = students_by_id[d["student_id"]]
    assignment = assignments_by_codename[d["assignment"]]

    evaluations = [
        rebuild_evaluation_from_dict(e)
        for e in d["evaluations"]
    ]

    score = Score(
        d["score"]["earned"],
        d["score"]["total"],
        d["score"]["percent"],
        d["score"]["letter"]
    )

    return Submission(
        student,
        assignment,
        DateTime(d["submitted_at"]),
        score,
        evaluations
    )
end

function rebuild_gradebook_from_dict(data::Dict)
    # Rebuild lookup tables first
    students_by_id = Dict{Any,Any}()
    assignments_by_codename = Dict{String,Any}()

    # Rebuild students
    for sdata in data["students"]
        s = rebuild_student_from_dict(sdata)
        students_by_id[s.id] = s
    end

    # Rebuild assignments (questions/rubric trees)
    for adata in data["assignments"]
        a = rebuild_assignment_from_dict(adata)
        assignments_by_codename[a.codename] = a
    end

    # Rebuild class / roster / course
    course = rebuild_course_from_dict(data["course"])
    roster = rebuild_roster_from_dict(data["roster"], students_by_id)
    cls = rebuild_class_from_dict(data["class"], course, roster)

    # Rebuild submissions
    submissions = [
        rebuild_submission_from_dict(sdata, students_by_id, assignments_by_codename)
        for sdata in data["submissions"]
    ]

    # Replace the constructor call below with the exact constructor you use
    return Gradebook(cls, submissions)
end

function import_gradebook(path::AbstractString)
    data = JSON.parsefile(path)
    return rebuild_gradebook_from_dict(data)
end
