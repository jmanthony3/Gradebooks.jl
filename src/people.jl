export fetch_name, fetch_codename
export AbstractPerson, Instructor, Student

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
        new(name_given, name_family, name_title, name_suffix, name_preferred, uppercase2symbol(name_initials),
            email, phone, organization, job_title, id, name, uppercase2symbol(codename))
    end
end
function Instructor(name_given, name_family; name_title="", name_suffix="", name_preferred="", name_initials="", email="", phone="", organization="", job_title="", id="")
    organization = isempty(organization) ? ORGANIZATION : organization
    name = fetch_name(name_given, name_family; title=name_title, suffix=name_suffix, nickname=name_preferred)
    codename = !isempty(name_initials) ? uppercase2symbol(name_initials) : fetch_codename(name_given, name_family; nickname=name_preferred)
    return Instructor(name_given, name_family, name_title, name_suffix, name_preferred, codename, email, phone, organization, job_title, id, name, codename)
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
        new(name_given, name_family, name_title, name_suffix, name_preferred, uppercase2symbol(name_initials),
            email, phone, organization, discipline, id, name, uppercase2symbol(codename))
    end
end
function Student(name_given, name_family; name_title="", name_suffix="", name_preferred="", name_initials="", email="", phone="", organization="", discipline="", id="")
    organization = isempty(organization) ? ORGANIZATION : organization
    name = fetch_name(name_given, name_family; title=name_title, suffix=name_suffix, nickname=name_preferred)
    codename = !isempty(name_initials) ? uppercase2symbol(name_initials) : fetch_codename(name_given, name_family; nickname=name_preferred)
    return Student(name_given, name_family, name_title, name_suffix, name_preferred, codename, email, phone, organization, discipline, id, name, codename)
end
