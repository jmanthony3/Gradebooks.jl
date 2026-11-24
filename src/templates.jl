public RelativeDate, AssignmentTemplate, CourseTemplate
export load_course_template
export absolute_date, resolve



using Dates, TOML



@kwdef struct RelativeDate
    week::Integer   # 1-based week of the term
    day::Integer    # day of that week
    # optional time of day
    time::Union{Nothing, Time} = nothing
end

@kwdef struct AssignmentTemplate
    name::String
    value::Credit
    due::RelativeDate
    category::AssignmentCategory
    is_group::Bool
    questions::Vector{Question}
    codename::Union{Nothing, String} = nothing
    # assigned::RelativeDate
    # any other static metadata (rubric, questions, etc.)
    # extras::NamedTuple = (;)
end

struct CourseTemplate
    code::String
    number::Integer
    name::String
    credits::Integer
    assignments::Vector{AssignmentTemplate}
    # codename::Symbol
    # optional: default attendance policy, grading weights, etc.
end

function rubric_parts(rubrics, rubric_name)
    index = findfirst(r -> get(r, "name", nothing) == rubric_name, rubrics)
    isnothing(index) && throw(ArgumentError("Unknown rubric: $rubric_name"))

    parts = get(rubrics[index], "parts", nothing)
    isnothing(parts) && throw(ArgumentError("Rubric '$rubric_name' has no parts"))
    isempty(parts) && throw(ArgumentError("Rubric '$rubric_name' has no parts"))

    return [
        Question(p["name"], (haskey(p, "percent") ? Percent(get(p, "percent", 0)) : Point(get(p, "point", 0))))
        for p in parts
    ]
end

function template_question(spec, rubrics)
    haskey(spec, "rubric") && haskey(spec, "parts") &&
        throw(ArgumentError("Question '$(spec["name"])' cannot have both 'rubric' and 'parts'"))

    parts = if haskey(spec, "rubric")
        rubric_parts(rubrics, spec["rubric"])
    elseif haskey(spec, "parts")
        [template_question(p, rubrics) for p in spec["parts"]]
    else
        nothing
    end

    return Question(spec["name"], (haskey(spec, "percent") ? Percent(get(spec, "percent", 0)) : Point(get(spec, "point", 0))), parts)
end

function template_questions(assignment, rubrics)
    haskey(assignment, "rubric") && haskey(assignment, "questions") &&
        throw(ArgumentError("Assignment '$(assignment["name"])' cannot have both 'rubric' and 'questions'"))

    if haskey(assignment, "rubric")
        # Represent an assignment-level rubric as one question with percentage parts.
        return [Question(
            assignment["name"],
            (haskey(assignment, "percent") ? Percent(get(assignment, "percent", 0)) : Point(get(assignment, "point", 0))),
            rubric_parts(rubrics, assignment["rubric"]),
        )]
    end

    return [
        template_question(q, rubrics)
        for q in get(assignment, "questions", [])
    ]
end

function find_template_file(course_code; template=nothing, templates_dir)
    project_file = Base.active_project()
    project_dir = isnothing(project_file) ? pwd() : dirname(project_file)

    filename = isnothing(template) ?
        "Gradebook.toml" :
        "Gradebook-$template.toml"

    candidates = [
        joinpath(project_dir, filename),
        joinpath(templates_dir, course_code, filename),
    ]

    path = findfirst(isfile, candidates)
    isnothing(path) && throw(TemplateError(filename, candidates))

    return candidates[path]
end

function load_course_template(course_code::AbstractString;
                              template=nothing,
                              templates_dir=joinpath(pwd(), "..", "templates"))
    file = find_template_file(course_code; template, templates_dir)
    data = TOML.parsefile(file)

    meta = data["course"]

    assignments = map(data["assignments"]) do a
        # assigned = RelativeDate(
        #     a["assigned"]["week"],
        #     Symbol(a["assigned"]["day"]);
        #     time = get(a["assigned"], "time", nothing) === nothing ? nothing : Time(a["assigned"]["time"])
        # )
        due = RelativeDate(
            a["due"]["week"],
            a["due"]["day"],
            get(a["due"], "time", nothing) === nothing ? nothing : Time(a["due"]["time"])
        )

        # @show a["name"], due, a["value"], a["category"], get(a, "is_group", false), get(a, "questions", Question[])

        questions = template_questions(a, get(data, "rubrics", []))

        # @show get(a, "codename", a["name"])
        AssignmentTemplate(
            a["name"],
            (haskey(a, "percent") ? Percent(get(a, "percent", 0)) : Point(get(a, "point", 0))),
            due,
            get(CATEGORY, lowercase(replace(a["category"], "_Assignment" => "")), error("Unknown assignment category: $(a["category"])")),
            # assigned,
            get(a, "is_group", false),
            questions,
            get(a, "codename", a["name"])
        )
    end

    # @show meta["code"], meta["number"], meta["name"], meta["credits"]

    return CourseTemplate(
        meta["code"],
        isa(meta["number"], AbstractString) ? parse(Int, meta["number"]) : meta["number"],
        meta["name"],
        meta["credits"],
        assignments
    )
end


function absolute_date(start::Date, rel::RelativeDate)
    1 ≤ rel.day ≤ 7 || throw(TemplateError("day must be 1–7 (Sun–Sat); got $(rel.day)"))
    rel.week ≥ 1    || throw(TemplateError("week must be ≥ 1; got $(rel.week)"))
    sunday = start - Day(dayofweek(start) % 7)          # Sunday of week 1
    return DateTime(sunday + Week(rel.week - 1) + Day(rel.day - 1),
                    something(rel.time, MIDNIGHT))
end

"""
    resolve(template::CourseTemplate, start::Date; roster, section=..., kwargs...) → Class / Gradebook pieces

Turn relative week/day offsets into absolute Dates using the semester start date.
"""
function resolve(template::CourseTemplate, term::Term, section, frequency, time_start, time_finish, roster::Roster, instructors...; kwargs...)
    assignments = map(template.assignments) do t
        make_assignment(
            t.name,
            t.value,
            absolute_date(term.start, t.due),
            t.category,
            t.is_group,
            !isempty(t.questions) ? t.questions : nothing,
            t.codename,
            # assigned,
            # t.extras...
        )
    end
    course = Course(template.code, template.number, template.name; credits=template.credits, assignments=assignments)
    return Class(course, term, section, frequency, time_start, time_finish, collect(instructors), roster.students, kwargs...)
end
