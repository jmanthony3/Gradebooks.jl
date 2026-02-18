export fetch_name, fetch_codename
export AbstractPerson, Instructor, Student, Team
export modify_info, get_student, modify_roster!, fetch_emails

using JSON

fetch_name(given, family; title="", suffix="", nickname="") = join(filter(!isnothing, [(isempty(title) ? nothing : (title=strip(title); last(title) == '.' ? title : "$title.")), given, (isempty(nickname) ? nothing : "\"$nickname\""), family]), " ") * (suffix == "" ? "" : (first(suffix) == ',' ? suffix : ", $suffix"))
fetch_codename(given, family; nickname="") = uppercase2symbol(join(map(s->first(s, 1), [!isempty(nickname) ? nickname : given, family])))

abstract type AbstractPerson end

struct Instructor <: AbstractPerson
    name_given::String
    name_family::String
    name_title::String
    name_suffix::String
    name_preferred::String
    name_initials::Symbol
    email::String
    phone::String
    organization::String
    job_title::String
    id::String
    name::String
    codename::Symbol
    function Instructor(name_given, name_family, name_title, name_suffix, name_preferred, name_initials, email, phone, organization, job_title, id, name, codename)
        organization = isempty(organization) ? ORGANIZATION : organization
        name = fetch_name(name_given, name_family; title=name_title, suffix=name_suffix, nickname=name_preferred)
        codename = name_initials != "" ? uppercase2symbol(name_initials) : fetch_codename(name_given, name_family; nickname=name_preferred)
        new(name_given, name_family, name_title, name_suffix, name_preferred, uppercase2symbol(codename),
            email, phone, organization, job_title, id, name, uppercase2symbol(codename))
    end
end
function Instructor(name_given, name_family; name_title="", name_suffix="", name_preferred="", name_initials="", email="", phone="", organization="", job_title="", id="")
    organization = isempty(organization) ? ORGANIZATION : organization
    name = fetch_name(name_given, name_family; title=name_title, suffix=name_suffix, nickname=name_preferred)
    codename = !isempty(name_initials) ? uppercase2symbol(name_initials) : fetch_codename(name_given, name_family; nickname=name_preferred)
    return Instructor(name_given, name_family, name_title, name_suffix, name_preferred, "$codename", email, phone, organization, job_title, id, name, codename)
end

struct Student <: AbstractPerson
    name_given::String
    name_family::String
    name_title::String
    name_suffix::String
    name_preferred::String
    name_initials::Symbol
    email::String
    phone::String
    organization::String
    discipline::String
    id::String
    name::String
    codename::Symbol
    function Student(name_given, name_family, name_title, name_suffix, name_preferred, name_initials, email, phone, organization, discipline, id, name, codename)
        organization = isempty(organization) ? ORGANIZATION : organization
        name = fetch_name(name_given, name_family; title=name_title, suffix=name_suffix, nickname=name_preferred)
        codename = name_initials != "" ? uppercase2symbol(name_initials) : fetch_codename(name_given, name_family; nickname=name_preferred)
        new(name_given, name_family, name_title, name_suffix, name_preferred, uppercase2symbol(codename),
            email, phone, organization, discipline, id, name, uppercase2symbol(codename))
    end
end
function Student(name_given, name_family; name_title="", name_suffix="", name_preferred="", name_initials="", email="", phone="", organization="", discipline="", id="")
    organization = isempty(organization) ? ORGANIZATION : organization
    name = fetch_name(name_given, name_family; title=name_title, suffix=name_suffix, nickname=name_preferred)
    codename = !isempty(name_initials) ? uppercase2symbol(name_initials) : fetch_codename(name_given, name_family; nickname=name_preferred)
    return Student(name_given, name_family, name_title, name_suffix, name_preferred, "$codename", email, phone, organization, discipline, id, name, codename)
end

struct Team
    name::String
    students::Vector{Student}
    codename::Symbol
    function Team(name, students, codename)
        codename = if isa(codename, Symbol)
            codename
        elseif isa(codename, String)
            string2codename(codename)
        else
            @error "`codename` must be of type Symbol or String."
        end
        return new(join(map(t->(first(t, 2) == "\\{" && last(t, 2) == "\\}") ? "{$(t[begin+2:end-2])}" : ((first(t) == '{' && last(t) == '}') ? t[begin+1:end-1] : t), split(name, " ")), " "), students, uppercase2symbol(codename))
    end
end
Team(name, students) = Team(name, students, name)

function modify_info(person::T, keyvaluepairs) where {T<:AbstractPerson}
    props = propertynames(person)
    vals = map(property->getproperty(person, property), props)
    nt = NamedTuple{props}(vals)
    for (key, value) in pairs(keyvaluepairs)
        nt = merge(nt, eval(:( ($key=$value,) )))
    end
    return T(nt...)
end

function get_student(roster::Vector{Student}, identifier::String)
    x = string.(split(identifier, ", "))
    a, b, c = if length(x) == 2
        x..., :name
    else
        y = string.(split(identifier, "@"))
        if length(y) == 2
            y..., :email
        else
            only(y), "", :any
        end
    end
    return if c == :name
        roster[findfirst(x->(x.name_family == a) && (x.name_given == b || x.name_preferred == b), roster)]
    elseif c == :email
        roster[findfirst(x->string(split(x.email, "@")[1]) == a, roster)]
    elseif c == :any
        roster[findfirst(x->any(y->occursin(a, repr(getproperty(x, y))), propertynames(x)), roster)]
    end
end

function modify_roster!(roster, student, info)
    roster[findfirst(x->x == student, roster)] = modify_info(student, info)
    return nothing
end

function fetch_emails(roster::Vector{Student}; search=nothing)
    emails = []
    for student in roster
        email = student.email
        # username, domain = split(email, "@")
        # if domain != ORG_EMAILDOMAIN
        #     email = username * "@" * ORG_EMAILDOMAIN
        # end
        push!(emails, email)
    end
    return if search == :outlook
        join(map(e->"from:$e", emails), " OR ")
    else
        emails
    end
end
