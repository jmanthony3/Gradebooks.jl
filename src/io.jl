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


function flatten_question(q::Question)
    return Dict(
        "kind" => "Question",
        "name" => q.name,
        "value" => q.value,
        "value_type" => typeof(q.value),
        "parts" => isnothing(q.parts) ? q.parts : flatten_question.(q.parts),
        "codename" => q.codename
    )
end

function flatten_assignment(a::Assignment)
    return Dict(
        "kind" => "Assignment",
        "name" => a.name,
        "value" => a.value,
        "due" => a.due,
        "category" => a.category,
        "is_group" => a.is_group,
        "questions" => flatten_question.(a.questions),
        "codename" => a.codename
    )
end

function flatten_course(c::Course)
    return Dict(
        "kind" => "Course",
        "code" => c.code,
        "number" => c.number,
        "name" => c.name,
        "credits" => c.credits,
        "assignments" => flatten_assignment(c.assignments),
        "codename" => c.codename
    )
end

function flatten_term(t::Term)
    return Dict(
        "kind" => "Term",
        "name" => t.name,
        "calendar_type" => t.calendar_type,
        "year" => t.year,
        "start" => t.start,
        "finish" => t.finish,
        "holidays" => t.holidays,
        "code" => t.code,
        "metadata" => t.metadata
    )
end

function flatten_person(p::Person)
    return Dict(
        "kind" => "Person",
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

function flatten_instructor(s::Instructor)
    return Dict(
        "kind" => "Instructor",
        "person" => flatten_person(s.person),
        "job_title" => s.job_title,
        "notes" => flatten_dict(s.notes)
    )
end

function flatten_lettergrade(lg::LetterGrade)
    return Dict(
        "kind" => "LetterGrade",
        "level" => lg.level,
        "string" => lg.string,
        "quality_points" => lg.quality_points
    )
end

function flatten_student(s::Student)
    return Dict(
        "kind" => "Student",
        "person" => flatten_person(s.person),
        "discipline" => s.discipline,
        "enrollment_status" => string(s.enrollment_status),
        "final_grade" => isnothing(s.final_grade) ? nothing : flatten_lettergrade(s.final_grade),
        "withdrawal_date" => s.withdrawal_date,
        "notes" => flatten_dict(s.notes)
    )
end

function flatten_class(c::Class)
    return Dict(
        "kind" => "Class",
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

function flatten_score(s::Score)
    return Dict(
        "kind" => "Score",
        "earned" => s.earned,
        "value" => s.value,
        "percent" => s.percent,
        "letter" => flatten_lettergrade(s.letter),
        "comment" => s.comment
    )
end

function flatten_mark(m::Mark)
    return Dict(
        "kind" => "Mark",
        "delta" => m.delta,
        "delta_type" => typeof(m.delta),
        "comment" => m.comment
    )
end

function flatten_evaluation(e::Evaluation)
    return Dict(
        "kind" => "Evaluation",
        "target" => flatten_question(e.target),
        "mark" => flatten_mark(e.mark),
        "comment" => e.comment
    )
end

function flatten_submission(s::Submission)
    return Dict(
        "kind" => "Submission",
        "submitted" => s.submitted,
        "score" => flatten_score(s.score),
        "evaluations" => flatten_evaluation.(s.evaluations)
    )
end

function flatten_grade(g::Grade)
    return Dict(
        "kind" => "Grade",
        "student" => flatten_student(g.student),
        "assignment" => flatten_assignment(g.assignment),
        "submission" => flatten_submission(g.submission)
    )
end

function flatten_attendancerecord(ar::AttendanceRecord)
    return Dict(
        "kind" => "AttendanceRecord",
        "status" => ar.status,
        "stamp" => ar.stamp,
        "comment" => ar.comment
    )
end

function flatten_cell(x)
    if isa(x, AttendanceRecord)
        return flatten_attendancerecord(x)
    elseif isa(x, Grade)
        return flatten_grade(x)
    elseif isa(x, Point)
        return Dict("kind" => "Point", "val" => x.val)
    elseif isa(x, Percent)
        return Dict("kind" => "Percent", "val" => x.val)
    elseif isa(x, Nothing)
        return nothing
    else
        return x
    end
end

function flatten_dataframe(df::DataFrame)
    return Dict(
        "kind" => "DataFrame",
        "columns" => String.(names(df)),
        "rows" => [[flatten_cell(df[i, j]) for j in 1:ncol(df)] for i in 1:nrow(df)]
    )
end

function flatten_gradebook(gb::Gradebook)
    return Dict(
        "kind" => "Gradebook",
        "schema_version" => string(pkgversion(@__MODULE__)),
        "saved_at" => string(now()),
        "class" => flatten_class(gb.class),
        "grades" => flatten_grade.(gb.grades),
        "raw" => flatten_dataframe(gb.raw),
        "penalty" => flatten_dataframe(gb.penalty),
        "total" => flatten_dataframe(gb.total)
    )
end

"Exports gradebook (`gb`) to `path` in `format` (`:json` or `:csv`) which can also be parsed from file extension."
function export_gradebook(gb::Gradebook, path::AbstractString; format::Union{Nothing, Symbol}=nothing)
    if lowercase(splitext(path)[2]) == ".json" || format == :json
        mkpath(dirname(path))
        open(path, "w") do io
            JSON.print(io, flatten_gradebook(gb), 4)
        end
    elseif lowercase(splitext(path)[2]) == ".csv" || format == :csv
        mkpath(dirname(path))
        CSV.write(path, gb.total)
    else
        error("Unsupported export format: $format")
    end
    return nothing
end


# --- JSON archive round-trip -------------------------------------------------


function rebuild_question_from_dict(d)
    value_type = (d["value_type"] == "Point" ? Point : (d["value_type"] == "Percent" ? Percent : error("Got unrecognized value type: ", d["value_type"])))
    return Question(
        d["name"],
        parse(value_type, d["value"]),
        d["parts"] == "nothing" ? nothing : rebuild_question_from_dict.(d["parts"]),
        Symbol(d["codename"])
    )
end

function rebuild_assignment_from_dict(d)
    category = findfirst(x->string(x)==d["category"], instances(AssignmentCategory))
    if !isnothing(category)
        return Assignment(
            d["name"],
            parse(Point, d["value"]),
            parse_datetime(d["due"]),
            instances(AssignmentCategory)[category],
            parse(Bool, d["is_group"]),
            rebuild_question_from_dict.(d["questions"]),
            Symbol(d["codename"])
        )
    else
        error("Unknown assignment category: $(d["category"])")
    end
end

function rebuild_course_from_dict(d)
    return Course(
        Symbol(d["code"]),
        parse(Integer, d["number"]),
        d["name"],
        parse(Integer, d["credits"]),
        rebuild_assignment_from_dict.(d["assignments"]),
        Symbol(d["codename"])
    )
end

function rebuild_term_from_dict(d)
    calendar_type = findfirst(x->string(x)==d["calendar_type"], instances(AcademicCalendarType))
    if !isnothing(calendar_type)
        return Term(
            d["name"],
            instances(AcademicCalendarType)[calendar_type],
            parse(Integer, d["year"]),
            parse_datetime(d["start"]),
            parse_datetime(d["finish"]),
            parse_datetime.(d["holidays"]),
            Symbol(d["code"]),
            d["metadata"]
        )
    else
        error("Unknown calendar type: $(d["calendar_type"])")
    end
end

function rebuild_person_from_dict(d)
    return Person(
        d["name_given"],
        d["name_family"],
        d["name_title"],
        d["name_suffix"],
        d["name_preferred"],
        Symbol(d["name_initials"]),
        d["name_aliases"],
        d["email"],
        d["phone"],
        d["organization"],
        d["id"],
        d["name"],
        Symbol(d["codename"])
    )
end

function rebuild_instructor_from_dict(d)
    return Instructor(
        rebuild_person_from_dict(d["person"]),
        d["job_title"],
        d["notes"]
    )
end

function rebuild_lettergrade_from_dict(d)
    level = findfirst(x->string(x)==d["level"], instances(GradeLevel))
    if !isnothing(level)
        return LetterGrade(
            instances(GradeLevel)[level],
            d["string"],
            parse(Real, d["quality_points"])
        )
    else
        error("Unknown grade level: $(d["level"])")
    end
end

function rebuild_student_from_dict(d)
    status = findfirst(x->string(x)==d["enrollment_status"], instances(EnrollmentStatus))
    if !isnothing(status)
        return Dict(
            rebuild_person_from_dict(d["person"]),
            d["discipline"],
            instances(EnrollmentStatus)[status],
            rebuild_lettergrade_from_dict(d["final_grade"]),
            (d["withdrawal_date"] == "nothing" ? nothing : parse_datetime(d["withdrawal_date"])),
            d["notes"]
        )
    else
        error("Unknown enrollment status: $(d["enrollment_status"])")
    end
end

function rebuild_roster_from_dict(d)
    return Roster(rebuild_student_from_dict.(d["roster"]))
end

function rebuild_class_from_dict(d)
    return Class(
        rebuild_course_from_dict(d["course"]),
        rebuild_term_from_dict(d["term"]),
        parse(Integer, d["section"]),
        Symbol.(d["frequency"]),
        parse_time(d["time_start"]),
        parse_time(d["time_finish"]),
        parse_time(d["time_duration"]),
        rebuild_assignment_from_dict.(d["lectures"]),
        Symbol(d["codename_short"]),
        Symbol(d["codename_long"]),
        rebuild_instructor_from_dict(d["primary_instructor"]),
        rebuild_instructor_from_dict.(d["instructors"]),
        rebuild_roster_from_dict(d["roster"])
    )
end

function rebuild_score_from_dict(d)
    return Score(
        parse(Point, d["earned"]),
        parse(Point, d["value"]),
        parse(Percent, d["percent"]),
        rebuild_lettergrade_from_dict(d["letter"]),
        d["comment"],
    )
end

function rebuild_mark_from_dict(d)
    return Mark(parse(d["delta_type"], d["delta"]), d["comment"])
end

function rebuild_evaluation_from_dict(d)
    return Evaluation(
        rebuild_question_from_dict(d["target"]),
        rebuild_mark_from_dict(d["mark"]),
        d["comment"]
    )
end

function rebuild_submission_from_dict(d)
    return Submission(
        parse_datetime(d["submitted"]),
        rebuild_score_from_dict(d["score"]),
        rebuild_evaluation_from_dict.(d["evaluations"]),
    )
end

function rebuild_grade_from_dict(d)
    return Grade(
        rebuild_student_from_dict(d["student"]),
        rebuild_assignment_from_dict(d["assignment"]),
        rebuild_submission_from_dict(d["submission"]),
    )
end

function rebuild_cell_from_dict(d, assignment, student)
    if d isa Dict && haskey(d, "kind")
        if !isnothing(assignment)
            if assignment.category == CategoryAttendance
                if d["kind"] == "AttendanceRecord"
                    status = findfirst(x->string(x)==d["status"], instances(AttendanceStatus))
                    if !isnothing(status)
                        return AttendanceRecord(
                            instances(AttendanceStatus)[status],
                            parse_datetime(d["stamp"]),
                            d["comment"]
                        )
                    else
                        error("Unknown combination of attendance status ($(d["status"])) or assignment category ($(assignment.category))")
                    end
                elseif d["kind"] == "Point"
                    return parse(Point, d["val"])
                elseif d["kind"] == "Percent"
                    return parse(Percent, d["val"])
                else
                    error("Unknown dataframe cell kind: $(d["kind"])")
                end
            elseif d["kind"] == "Grade" && (
                        rebuild_student_from_dict(d["student"]) == student &&
                        rebuild_assignment_from_dict(d["assignment"]) == assignment
                    )
                return Grade(
                    student,
                    assignment,
                    rebuild_submission_from_dict(d["submission"])
                )
            elseif d["kind"] == "Point"
                return parse(Point, d["val"])
            elseif d["kind"] == "Percent"
                return parse(Percent, d["val"])
            else
                error("Unknown dataframe cell kind: $(d["kind"])")
            end
        else
            error("Cannot ex nihilo dataframe cell from nothing assignment")
        end
    else
        return d
    end
end

function rebuild_dataframe_from_dict(d, assignments::Vector{Assignment}, students::Vector{Student})
    cols = Symbol.(d["columns"])
    rows = get(d, "rows", [])
    assignment_lookup = Dict(string(a.codename) => a for a in assignments)

    out = Dict{Symbol, Vector{Any}}()
    for (j, col) in enumerate(cols)
        colname = string(col)
        assignment = get(assignment_lookup, colname, nothing)
        values = Vector{Any}()
        for (i, row) in enumerate(rows)
            push!(values, rebuild_cell_from_dict(row[j], assignment, students[i]))
        end
        out[col] = values
    end

    return DataFrame(out)
end

function rebuild_gradebook_from_dict(d::Dict)
    class = rebuild_class_from_dict(d["class"])
    grades = rebuild_grade_from_dict.(d["grades"])

    assignments = class.course.assignments
    students = class.roster.students
    lectures = class.lectures
    assignments_and_lectures = vcat(assignments, lectures)
    raw = rebuild_dataframe_from_dict(d["raw"], assignments_and_lectures, students)
    penalty = rebuild_dataframe_from_dict(d["penalty"], assignments_and_lectures, students)
    total = rebuild_dataframe_from_dict(d["total"], assignments_and_lectures, students)

    return Gradebook(class, grades, raw, penalty, total)
end

function import_gradebook(path::AbstractString)
    if lowercase(splitext(path)[2]) == ".json"
        return rebuild_gradebook_from_dict(JSON.parsefile(path))
    else
        error("Can only import JSON file")
    end
end
