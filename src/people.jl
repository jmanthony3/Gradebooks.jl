export fetch_name, fetch_codename
export AbstractPerson, Instructor, Student

using JSON

fetch_name(given, family; title="", suffix="", nickname="") = join(filter(!isnothing, [(isempty(title) ? nothing : (title=strip(title); last(title) == '.' ? title : "$title.")), given, (isempty(nickname) ? nothing : "\"$nickname\""), family]), " ") * (suffix == "" ? "" : (first(suffix) == ',' ? suffix : ", $suffix"))
fetch_codename(given, family; nickname="") = uppercase(join(map(s->first(s, 1), [!isempty(nickname) ? nickname : given, family])))

abstract type AbstractPerson end

struct Instructor <: AbstractPerson
    name_given
    name_family
    name_title
    name_suffix
    name_preferred
    name_initials
    email
    phone
    organization
    job_title
    id
    name
    codename
end
function Instructor(name_given, name_family; name_title="", name_suffix="", name_preferred="", name_initials="", email="", phone="", organization="", job_title="", id="")
    name = fetch_name(name_given, name_family; title=name_title, suffix=name_suffix, nickname=name_preferred)
    codename = !isempty(name_initials) ? name_initials : fetch_codename(name_given, name_family; nickname=name_preferred)
    return Instructor(name_given, name_family, name_title, name_suffix, name_preferred, codename, email, phone, organization, job_title, id, name, codename)
end

struct Student <: AbstractPerson
    name_family
    lastname
    name_title
    name_suffix
    name_preferred
    name_initials
    email
    phone
    organization
    discipline
    id
    name
    codename
end
function Student(name_given, name_family; name_title="", name_suffix="", name_preferred="", name_initials="", email="", phone="", organization="", discipline="", id="")
    name = fetch_name(name_given, name_family; title=name_title, suffix=name_suffix, nickname=name_preferred)
    codename = !isempty(name_initials) ? name_initials : fetch_codename(name_given, name_family; nickname=name_preferred)
    return Student(name_given, name_family, name_title, name_suffix, name_preferred, codename, email, phone, organization, discipline, id, name, codename)
end
