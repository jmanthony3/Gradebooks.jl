export save_gradebook, load_gradebook, export_gradebook, import_gradebook

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

function save_archive(
    gb::Gradebook,
    path::AbstractString;
    history::Vector{ChangeEvent}=ChangeEvent[]
)
    archive = GradebookArchive(
        string(pkgversion(@__MODULE__)),
        now(),
        gb,
        history
    )

    mkpath(dirname(path))
    JLD2.jldsave(path; archive)
    return path
end

function load_archive(path::AbstractString)
    JLD2.jldopen(path, "r") do f
        read(f, "archive")
    end
end

function save_gradebook(
    gb::Gradebook,
    path::AbstractString;
    history::Vector{ChangeEvent}=ChangeEvent[]
)
    return save_archive(gb, path; history=history)
end

function load_gradebook(path::AbstractString)
    arc = load_archive(path)
    return arc.gradebook
end

# --- JSON archive round-trip -------------------------------------------------

function import_gradebook(path::AbstractString)
    data = JSON.parsefile(path)
    return rebuild_gradebook_from_dict(data)
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

# --- JSON export helpers -----------------------------------------------------

function flatten_class(c)
    return Dict(
        "course" => flatten_course(c.course),
        "roster" => Dict(
            "student_ids" => [s.id for s in c.roster.students]
        )
    )
end

function flatten_course(c)
    return Dict(
        "name" => c.name,
        "code" => c.code,
        "semester" => c.semester,
        "section" => c.section
    )
end

function flatten_student(s)
    return Dict(
        "id" => s.id,
        "email" => s.email,
        "name_given" => s.person.name_given,
        "name_family" => s.person.name_family,
        "name_preferred" => s.person.name_preferred,
        "enrollment_status" => string(s.enrollment_status),
        "final_grade" => s.final_grade === nothing ? nothing : string(s.final_grade)
    )
end

function flatten_item(item; prefix="")
    name = prefix == "" ? item.codename : "$(prefix).$(item.codename)"

    out = Dict(
        "codename" => item.codename,
        "label" => item.name,
        "value" => item.value
    )

    if hasproperty(item, :parts) && !isnothing(item.parts)
        out["parts"] = [flatten_item(p; prefix=name) for p in item.parts]
    end

    return out
end

function flatten_assignment(a)
    return Dict(
        "codename" => a.codename,
        "name" => a.name,
        "value" => a.value,
        "questions" => [flatten_item(q) for q in a.questions]
    )
end

function flatten_mark(m)
    if m isa Point
        return Dict("kind" => "Point", "value" => m.val)
    elseif m isa Percent
        return Dict("kind" => "Percent", "value" => m.val)
    else
        return Dict("kind" => string(typeof(m)), "value" => m)
    end
end

function flatten_evaluation(e)
    return Dict(
        "item" => e.item.codename,
        "mark" => flatten_mark(e.mark),
        "comment" => e.comment
    )
end

function flatten_submission(g)
    return Dict(
        "student_id" => g.student.id,
        "assignment" => g.assignment.codename,
        "submitted_at" => string(g.submitted_at),
        "score" => Dict(
            "earned" => g.score.earned,
            "total" => g.score.total,
            "percent" => g.score.percent,
            "letter" => string(g.score.letter)
        ),
        "evaluations" => [flatten_evaluation(e) for e in g.evaluations]
    )
end

function flatten_gradebook(gb::Gradebook)
    return Dict(
        "schema_version" => string(pkgversion(@__MODULE__)),
        "saved_at" => string(now()),
        "course" => flatten_course(gb.class.course),
        "class" => flatten_class(gb.class),
        "students" => [flatten_student(s) for s in gb.class.roster.students],
        "assignments" => [flatten_assignment(a) for a in gb.class.course.assignments],
        "submissions" => [flatten_submission(g) for g in gb.grades]
    )
end

function export_gradebook(gb::Gradebook, path::AbstractString; format::Symbol=:json)
    if format == :json
        data = flatten_gradebook(gb)
        mkpath(dirname(path))
        open(path, "w") do io
            JSON.print(io, data, 2)
        end
        return path
    elseif format == :csv
        mkpath(dirname(path))
        CSV.write(path, gb.total)
        return path
    else
        error("Unsupported export format: $format")
    end
end
