export SEMVER_REGEX, DATETIME_REGEX, dirbasenameextname, safe_archive_namestamp
export save, load



using CSV, DataFrames, JSON



# https://semver.org/#is-there-a-suggested-regular-expression-regex-to-check-a-semver-string
# https://regex101.com/r/Ly7O1x/3/
const SEMVER_REGEX = r"^(?P<major>0|[1-9]\d*)\.(?P<minor>0|[1-9]\d*)\.(?P<patch>0|[1-9]\d*)(?:-(?P<prerelease>(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+(?P<buildmetadata>[0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$"
# const DATETIME_REGEX = r"\d{8}T\d{9}"
const DATETIME_REGEX = r"^(?P<year>\d{4}})(?P<month>\d{2}})(?P<day>\d{2}})T(?P<hour>\d{2}})(?P<minute>\d{2}})(?P<second>\d{2}})(?P<millisecond>\d{3}})$"

dirbasenameextname(path) = ((dir, base) = (dirname(path), basename(path)); (name, ext) = splitext(base); (dir=dir, base=base, name=name, ext=ext))

function safe_archive_namestamp(path)
    if !isascii(path)
        @error "Path must be comprised of alphanumeric characters" path
    end
    dir, base, name, ext = dirbasenameextname(path)
    name_semver = split(name, "-v")
    semver = if length(name_semver) == 2
        name_semver[2]
    else
        string(pkgversion(Gradebooks))
    end
    version = VersionNumber(semver)
    if isempty(version.build)
        VersionNumber(version.major, version.minor, version.minor, version.patch, (safe_datetime_stamp(),))
    else
        dt = safe_datetime_stamp(match(DATETIME_REGEX, version.build[end]))
        build = Tuple(version.build[1:(length(version.build)-1)]..., dt)
        VersionNumber(version.major, version.minor, version.minor, version.patch, build)
    end
    return joinpath([dir, name * "-v" * version * ext])
end


function save(data::Dict, path)
    if lowercase(splitext(path)[2]) != ".json"
        path *= ".json"
    end
    open(safe_archive_namestamp(path), "w") do file
        write(file, JSON.json(data, 4))
    end
    return nothing
end

function save(data::DataFrame, path)
    if lowercase(splitext(path)[2]) != ".csv"
        path *= ".csv"
    end
    open(safe_archive_namestamp(path), "w") do file
        # TODO: add metadata comments to output files?
        CSV.write(file, data)
    end
    return nothing
end


_save(data::Vector{<:Dictable}, path) = save(append!(DataFrame(first(data)), map(d->DataFrame(d), data[2:end])), path)
save(data::Dictable, path) = save(Dict(data), path)
save(data::Vector{Instructor}, path="instructors") = _save(data, path)
save(data::Vector{Student}, path="students") = _save(data, path)
save(data::Vector{Course}, path="courses") = _save(data, path)


function save(data::Vector{<:AbstractAssignment}, path="assignments")
    df = DataFrame(first(data))
    append!(df, map(d->DataFrame(d), data[2:end]))
    datatypes = typeof.(data)
    assignment_categories = map(s->replace(repr(s), "Abstract"=>""), map(t->t.parameters[1], datatypes))
    assignment_types = map(t->repr(t.parameters[2]), datatypes)
    insertcols!(df, 1, ("Category"=>assignment_categories, "Type"=>assignment_types))
    save(df, path)
    return nothing
end

save(data::Vector{Assignment{AbstractAttendance, Y}}, path="attendance") where {Y<:AssignmentType} = save(data, path)
save(data::Vector{Assignment{AbstractExam, Y}}, path="exams") where {Y<:AssignmentType} = save(data, path)
save(data::Vector{Assignment{AbstractHomework, Y}}, path="homeworks") where {Y<:AssignmentType} = save(data, path)
save(data::Vector{Assignment{AbstractPaper, Y}}, path="papers") where {Y<:AssignmentType} = save(data, path)
save(data::Vector{Assignment{AbstractPresentation, Y}}, path="presentations") where {Y<:AssignmentType} = save(data, path)
save(data::Vector{Assignment{AbstractProject, Y}}, path="projects") where {Y<:AssignmentType} = save(data, path)
save(data::Vector{Assignment{AbstractQuiz, Y}}, path="quizzes") where {Y<:AssignmentType} = save(data, path)
save(data::Vector{Score}, path="scores") = _save(data, path)


function save(data::Indictable, path, fieldnames::Vararg{String})
    fieldnames = filter!(x->x ∉ fieldnames, fieldnames(data))
    save(Dict(zip(fieldnames, getproperty.(data, fieldnames))), path)
    return nothing
end

function save(data::Class, path="class")
    dir, base, name, ext = dirbasenameextname(path)
    name_parts = split(name, "+")
    if length(name_parts) == 2
        save(data.course,       joinpath([dir, join([join([name_parts[1], join(["course", name_parts[2]], ".")], "+"), ext])]))
        save(data.instructors,  joinpath([dir, join([join([name_parts[1], join(["instructors", name_parts[2]], ".")], "+"), ext])]))
        save(data.roster,       joinpath([dir, join([join([name_parts[1], join(["roster", name_parts[2]], ".")], "+"), ext])]))
        save(data,              joinpath([dir, join([join([name_parts[1], name_parts[2]], "+"), ext])]), ["course", "instructors", "students", "roster"])
    else
        save(data.course,       joinpath([dir, join([join([name_parts[1], "course"], "+"), ext])]))
        save(data.instructors,  joinpath([dir, join([join([name_parts[1], "instructors"], "+"), ext])]))
        save(data.roster,       joinpath([dir, join([join([name_parts[1], "roster"], "+"), ext])]))
        save(data,              joinpath([dir, join([name_parts[1], ext])]), ["course", "instructors", "students", "roster"])
    end
    return nothing
end

function save(data::Submission, path="submission")
    dir, base, name, ext = dirbasenameextname(path)
    name_parts = split(name, "+")
    if length(name_parts) == 2
        save(data.assignment,   joinpath([dir, join([join([name_parts[1], join(["assignment", name_parts[2]], ".")], "+"), ext])]))
        save(data.submitted,    joinpath([dir, join([join([name_parts[1], join(["datetime", name_parts[2]], ".")], "+"), ext])]))
        save(data.score,        joinpath([dir, join([join([name_parts[1], join(["score", name_parts[2]], ".")], "+"), ext])]))
    else
        save(data.assignment,   joinpath([dir, join([join([name_parts[1], "assignment"], "+"), ext])]))
        save(data.submitted,    joinpath([dir, join([join([name_parts[1], "datetime"], "+"), ext])]))
        save(data.score,        joinpath([dir, join([join([name_parts[1], "score"], "+"), ext])]))
    end
    return nothing
end

function save(data::Grade, path="grade")
    dir, base, name, ext = dirbasenameextname(path)
    name_parts = split(name, "+")
    if length(name_parts) == 2
        save(data.student,      joinpath([dir, join([join([name_parts[1], join(["student", name_parts[2]], ".")], "+"), ext])]))
        save(data.assignment,   joinpath([dir, join([join([name_parts[1], join(["assignment", name_parts[2]], ".")], "+"), ext])]))
        save(data.submission,   joinpath([dir, join([join([name_parts[1], join(["submission", name_parts[2]], ".")], "+"), ext])]))
    else
        save(data.student,      joinpath([dir, join([join([name_parts[1], "student"], "+"), ext])]))
        save(data.assignment,   joinpath([dir, join([join([name_parts[1], "assignment"], "+"), ext])]))
        save(data.submission,   joinpath([dir, join([join([name_parts[1], "submission"], "+"), ext])]))
    end
    return nothing
end

function save(data::Gradebook{Class}, path="gradebook")
    df = data.data
    sort!(df, ["Last", "Preferred"])
    dir, base, name, ext = dirbasenameextname(path)
    name_parts = split(name, "+")
    if length(name_parts) == 2
        save(df, joinpath([dir, join([join([name_parts[1], join(["class", name_parts[2]], ".")], "+"), ext])]))
    else
        save(df, joinpath([dir, join([join([name_parts[1], "class"], "+"), ext])]))
    end
    return nothing
end
function save(data::Gradebook{Student}, path="gradebook")
    df = data.data
    sort!(df, ["Last", "Preferred"])
    dir, base, name, ext = dirbasenameextname(path)
    name_parts = split(name, "+")
    if length(name_parts) == 2
        save(df, joinpath([dir, join([join([name_parts[1], join(["student", name_parts[2]], ".")], "+"), ext])]))
    else
        save(df, joinpath([dir, join([join([name_parts[1], join(["student", data.who.name_family, data.who.name_given], ".")], "+"), ext])]))
    end
    return nothing
end



# TODO: below must be converse of above
function load(class::Class, data::String="gradebook")
    data_name = join([class.codename_long, data], "-")
    data_names = filter(x->occursin(data_name, x), readdir(@__DIR__))
    data_names_strings = [split(x, "-"; limit=2)[1] for x in data_names]
    data_times_strings = [split(x, "-"; limit=2)[2] for x in data_names]
    data_times = [DateTime(x, ISODateTimeFormat) for x in data_times_strings]
    data_times_sorted = sortperm(data_times)
    data_names_strings = data_names_strings[data_times_sorted]
    data_times = data_times[data_times_sorted]
    # df = CSV.read(joinpath[@__DIR__, data_names_strings[end]], DataFrame)
    # return Gradebook{Class}(class, names(df), df)
    return Gradebook{Class}(class, CSV.read(joinpath[@__DIR__, data_names_strings[end]], DataFrame))
end
# fetch_class_attendance(class::Class) = _fetch_class_data(class, "attendance")

# function fetch_student_gradebook(student::Student, class::Class)
# end
