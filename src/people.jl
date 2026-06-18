public make_person_name, make_person_codename
export AbstractPerson, Person
export Instructor
export Student, StudentIndex, Roster, get_student
export get_emails
export Team, get_team

using StringDistances

# TODO: these probably need to be sanitized
make_person_name(given, family; title="", suffix="", nickname="") = join(filter(!isnothing, [(isempty(title) ? nothing : (title=strip(title); last(title) == '.' ? title : "$title.")), given, (isempty(nickname) ? nothing : "\"$nickname\""), family]), " ") * (suffix == "" ? "" : (first(suffix) == ',' ? suffix : ", $suffix"))
make_person_codename(given, family; nickname="") = uppercase2symbol(join(map(s->first(s, 1), [!isempty(nickname) ? nickname : given, family])))

abstract type AbstractPerson end

@kwdef struct Person
    name_given::String
    name_family::String
    name_title::String              = ""
    name_suffix::String             = ""
    name_preferred::String          = ""
    name_initials::Symbol           = Symbol("")
    name_aliases::Vector{String}    = String[]
    email::String                   = ""
    phone::String                   = ""
    organization::String            = ""
    id::String                      = ""
    name::String                    = ""
    codename::Symbol                = Symbol("")
    function Person(name_given, name_family, name_title, name_suffix, name_preferred, name_initials, name_aliases, email, phone, organization, id, name, codename)
        _organization = isempty(organization) ? INSTITUTION : organization
        _name = make_person_name(name_given, name_family; title=name_title, suffix=name_suffix, nickname=name_preferred)
        _codename = name_initials != "" ? uppercase2symbol(name_initials) : make_person_codename(name_given, name_family; nickname=name_preferred)
        new(name_given, name_family, name_title, name_suffix, name_preferred, uppercase2symbol(_codename),
            name_aliases, email, phone, _organization, id, _name, uppercase2symbol(_codename))
    end
end

struct Instructor <: AbstractPerson
    person::Person
    job_title::String
end
Instructor(name_given::String, name_family::String; kwargs...) = Instructor(Person(name_given, name_family, kwargs...), kwargs.job_title)

@enum EnrollmentStatus begin
    Active
    Withdrawn
    Incomplete
    Graduated
end

@kwdef struct Student <: AbstractPerson
    person::Person
    discipline::String
    enrollment_status::EnrollmentStatus = Active
    final_grade::Union{Nothing, LetterGrade} = nothing
    withdrawal_date::Union{Nothing, Date} = nothing
    # reinstatement_date, notes, etc.
    notes::Dict{Symbol,Any} = Dict()
end
Student(name_given::String, name_family::String; kwargs...) = Student(Person(name_given, name_family, kwargs...), kwargs.discipline, kwargs.enrollment_status, kwargs.final_grade, kwargs.withdrawal_date, kwargs.notes)

struct StudentIndex
    by_email::Dict{String, Int}
    by_id::Dict{String, Int}
    by_codename::Dict{Symbol, Int}
    by_alias::Dict{String, Int}
    by_name::Dict{String, Int}
end

function StudentIndex(students::Vector{Student})
    idx = StudentIndex(Dict(), Dict(), Dict(), Dict(), Dict())
    for (i, s) in enumerate(students)
        haskey(idx.by_email, s.email) || (idx.by_email[s.email] = i)
        haskey(idx.by_id, s.id) || (idx.by_id[s.id] = i)
        haskey(idx.by_codename, s.codename) || (idx.by_codename[s.codename] = i)
        for alias in s.name_aliases
            haskey(idx.by_alias, alias) || (idx.by_alias[alias] = i)
        end
        haskey(idx.by_name, s.name) || (idx.by_name[s.name] = i)
    end
    return idx
end

struct Roster
    students::Vector{Student}
    index::StudentIndex
end
function Roster(students)
    return new(students, StudentIndex(students))
end

function student_candidates(s::Student)
    parts = String[
        s.name_family,
        s.name_given,
        s.name_preferred,
        s.email,
        split(s.email, "@")[1],
        string(s.id),
    ]
    return unique(filter(!isempty, map(sanitize_string, parts)))
end

function get_student(identifier::String, roster::Roster; threshold=STRING_MATCH_THRESHOLD)
    q = sanitize_string(identifier)

    # 1) exact matches first
    exact = findall(s -> any(c -> sanitize_string(c) == q, student_candidates(s)), roster.students)
    if length(exact) == 1
        return roster.students[exact[1]]
    end
    if length(exact) > 1
        error("Ambiguous student match for $(identifier): $(map(x -> x.email, roster.students[exact]))")
    end

    # 2) fuzzy fallback
    scores = Tuple{Student, String, Int}[]
    for s in roster.students
        for c in student_candidates(s)
            d = Levenshtein()(q, sanitize_string(c))
            push!(scores, (s, c, d))
        end
    end

    sort!(scores, by=x -> x[3])
    best_student, best_candidate, best_dist = scores[1]

    denom = max(length(q), length(sanitize_string(best_candidate)))
    if denom > 0 && best_dist / denom < threshold
        return best_student
    end

    error("Student not found: $(identifier)")
end

# function get_student(identifier::String, roster::Vector{Student}, index::StudentIndex; threshold=STRING_MATCH_THRESHOLD)
#     # exact matches first
#     for d in (index.by_email, index.by_id, index.by_codename)
#         haskey(d, identifier) && return roster[d[identifier]]
#     end

#     # if is username without "@<organization>.<domain>"
#     if occursin('@', identifier)
#         username = split(identifier, '@')[1]
#         haskey(index.by_email, username) && return roster[index.by_email[username]]
#     end

#     # fuzzy fallback
#     dist = Levenshtein()
#     best_student, best_dist = findnearest(identifier, [s.name for s in roster], dist)

#     if best_dist / max(length(identifier), length(best_student)) < threshold
#         return roster[findfirst(s -> s.name == best_student, roster)]
#     end

#     error("Student not found: $identifier. Closest was $best_student (distance too high)")
#     return roster[findfirst(x->any(y->occursin(a, repr(getproperty(x, y))), propertynames(x)), roster)]
# end

function update(person::Person; kwargs...)
    return update(person; kwargs...)
end

function update(student::Student; kwargs...)
    discipline          = student.discipline        == kwargs.discipline            ? student.discipline            : kwargs.discipline
    enrollment_status   = student.enrollment_status == kwargs.enrollment_status     ? student.enrollment_status     : kwargs.enrollment_status
    final_grade         = student.final_grade       == kwargs.final_grade           ? student.final_grade           : kwargs.final_grade
    withdrawal_date     = student.withdrawal_date   == kwargs.withdrawal_date       ? student.withdrawal_date       : kwargs.withdrawal_date
    notes               = student.notes             == kwargs.notes                 ? student.notes                 : kwargs.notes
    return Student(update(student.person; kwargs...), discipline, enrollment_status, final_grade, withdrawal_date, notes)
end

function update(roster::Roster, student::Union{String, Student}; threshold=STRING_MATCH_THRESHOLD, kwargs...)
    s = isa(student, String) ? get_student(student, roster; threshold=threshold) : student
    i = roster.index.by_id[s.id]   # or whatever key you want to use
    roster.students[i] = update(s; kwargs...)
    return Roster(roster.students)
end

function get_emails(roster::Roster; search=nothing)
    emails = []
    for student in roster.students
        email = student.email
        # username, domain = split(email, "@")
        # if domain != INSTITUTION_EMAILDOMAIN
        #     email = username * "@" * INSTITUTION_EMAILDOMAIN
        # end
        push!(emails, email)
    end
    return if search == :outlook
        join(map(e->"from:$e", emails), " OR ")
    else
        emails
    end
end

struct Team
    name::String
    students::Roster
    codename::Symbol
    function Team(name, students, codename)
        codename = if isa(codename, Symbol)
            codename
        elseif isa(codename, String)
            sanitize2codify(codename)
        else
            @error "`codename` must be of type Symbol or String."
        end
        return new(join(map(t->(first(t, 2) == "\\{" && last(t, 2) == "\\}") ? "{$(t[begin+2:end-2])}" : ((first(t) == '{' && last(t) == '}') ? t[begin+1:end-1] : t), split(name, " ")), " "), students, uppercase2symbol(codename))
    end
end
Team(name, students::Roster) = Team(name, students, name)
Team(name, students::Vector{Student}) = Team(name, Roster(students))

function get_team(identifier::String, teams::Vector{Team}; threshold=STRING_MATCH_THRESHOLD)
    q = sanitize_string(identifier)

    # 1) exact matches first
    exact = findall(s -> any(c -> sanitize_string(c) == q, student_candidates(s)), teams)
    if length(exact) == 1
        return teams[exact[1]]
    end
    if length(exact) > 1
        error("Ambiguous team match for $(identifier): $(map(x -> x.name, teams[exact]))")
    end

    # 2) fuzzy fallback
    scores = Tuple{Team, String, Int}[]
    for s in teams
        for c in student_candidates(s)
            d = Levenshtein()(q, sanitize_string(c))
            push!(scores, (s, c, d))
        end
    end

    sort!(scores, by=x -> x[3])
    best_team, best_candidate, best_dist = scores[1]

    denom = max(length(q), length(sanitize_string(best_candidate)))
    if denom > 0 && best_dist / denom < threshold
        return best_team
    end

    error("Team not found: $(identifier)")
end
