export name, codename
export AbstractPerson, Instructor, Student

name(firstname, lastname; title="", suffix="", nickname="") = join(filter(!isnothing, [(isempty(title) ? nothing : (title=strip(title); last(title) == '.' ? title : "$title.")), firstname, (isempty(nickname) ? nothing : "\"$nickname\""), lastname]), " ") * (suffix == "" ? "" : (first(suffix) == ',' ? suffix : ", $suffix"))
codename(firstname, lastname; nickname="") = uppercase(join(map(s->first(s, 1), [!isempty(nickname) ? nickname : firstname, lastname])))

abstract type AbstractPerson end

struct Instructor <: AbstractPerson
    firstname
    lastname
    title
    suffix
    nickname
    initials
    email
    phone
    organization
    job_title
    id
    name
    codename
    function Instructor(firstname, lastname; title="", suffix="", nickname="", initials="", email="", phone="", organization="", job_title="", id="")
        name = name(firstname, lastname; title=title, suffix=suffix, nickname=nickname)
        codename = !isempty(initials) ? initials : codename(firstname, lastname; nickname=nickname)
        return new(firstname, lastname, title, suffix, nickname, codename, email, phone, organization, job_title, id, name, codename)
    end
end

struct Student <: AbstractPerson
    firstname
    lastname
    title
    suffix
    nickname
    initials
    email
    phone
    organization
    discipline
    id
    name
    codename
    function Student(firstname, lastname; title="", suffix="", nickname="", initials="", email="", phone="", organization="", discipline="", id="")
        name = name(firstname, lastname; title=title, suffix=suffix, nickname=nickname)
        codename = !isempty(initials) ? initials : codename(firstname, lastname; nickname=nickname)
        return new(firstname, lastname, title, suffix, nickname, codename, email, phone, organization, discipline, id, name, codename)
    end
end