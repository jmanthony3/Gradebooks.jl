export dirbasenameextname, save
export fetch_class_gradebook, fetch_student_gradebook



using CSV, DataFrames, JSON



dirbasenameextname(path) = ((dir, base) = (dirname(path), basename(path)); (name, ext) = splitext(base); (dir=dir, base=base, name=name, ext=ext))



function save(data::Dict, path)
    if lowercase(splitext(path)[2]) != ".json"
        path *= ".json"
    end
    open(path, "w") do file
        write(file, JSON.json(data, 4))
    end
    return nothing
end

function save(data::DataFrame, path)
    if lowercase(splitext(path)[2]) != ".csv"
        path *= ".csv"
    end
    open(path, "w") do file
        CSV.write(file, data)
    end
    return nothing
end


_save(data::Vector{<:Dictable}, path) = save(append!(DataFrame(first(data)), map(d->DataFrame(d), data[2:end])), path)
save(data::Dictable, path) = save(Dict(data), path)
save(data::Vector{Instructor}, path=joinpath([pwd(), "instructors.csv"])) = _save(data, path)
save(data::Vector{Student}, path=joinpath([pwd(), "students.csv"])) = _save(data, path)
save(data::Vector{Course}, path=joinpath([pwd(), "courses.csv"])) = _save(data, path)


function save(data::Vector{<:AbstractAssignment}, path=joinpath([pwd(), "assignments.csv"]))
    df = DataFrame(first(data))
    append!(df, map(d->DataFrame(d), data[2:end]))
    datatypes = typeof.(data)
    assignment_categories = map(s->replace(repr(s), "Abstract"=>""), map(t->t.parameters[1], datatypes))
    assignment_types = map(t->repr(t.parameters[2]), datatypes)
    insertcols!(df, 1, ("Category"=>assignment_categories, "Type"=>assignment_types))
    save(df, path)
    return nothing
end

save(data::Vector{Assignment{AbstractAttendance, Y}}, path=joinpath([pwd(), "attendance.csv"])) where {Y<:AssignmentType} = save(data, path)
save(data::Vector{Assignment{AbstractExam, Y}}, path=joinpath([pwd(), "exams.csv"])) where {Y<:AssignmentType} = save(data, path)
save(data::Vector{Assignment{AbstractHomework, Y}}, path=joinpath([pwd(), "homeworks.csv"])) where {Y<:AssignmentType} = save(data, path)
save(data::Vector{Assignment{AbstractPaper, Y}}, path=joinpath([pwd(), "papers.csv"])) where {Y<:AssignmentType} = save(data, path)
save(data::Vector{Assignment{AbstractPresentation, Y}}, path=joinpath([pwd(), "presentations.csv"])) where {Y<:AssignmentType} = save(data, path)
save(data::Vector{Assignment{AbstractProject, Y}}, path=joinpath([pwd(), "projects.csv"])) where {Y<:AssignmentType} = save(data, path)
save(data::Vector{Assignment{AbstractQuiz, Y}}, path=joinpath([pwd(), "quizzes.csv"])) where {Y<:AssignmentType} = save(data, path)
save(data::Vector{Score}, path=joinpath([pwd(), "scores.csv"])) = _save(data, path)


function save(data::Indictable, path, fieldnames::Vararg{String})
    fieldnames = filter!(x->x ∉ fieldnames, fieldnames(data))
    save(Dict(zip(fieldnames, getproperty.(data, fieldnames))), path)
    return nothing
end

function save(data::Class, path)
    dir, base, name, ext = dirbasenameextname(path)
    name_parts = split(name, "+")
    if length(name_parts) == 2
        save(data.course,       joinpath([dir, join([join([string(name_parts[1]), join(["class.course", string(name_parts[2])], ".")], "+"), ext])]))
        save(data.instructors,  joinpath([dir, join([join([string(name_parts[1]), join(["class.instructors", string(name_parts[2])], ".")], "+"), ext])]))
        save(data.roster,       joinpath([dir, join([join([string(name_parts[1]), join(["class.roster", string(name_parts[2])], ".")], "+"), ext])]))
        save(data,              joinpath([dir, join([join([string(name_parts[1]), join(["class", string(name_parts[2])], ".")], "+"), ext])]), ["course", "instructors", "students", "roster"])
    else
        save(data.course,       joinpath([dir, join([join([string(name_parts[1]), "class.course"], "+"), ext])]))
        save(data.instructors,  joinpath([dir, join([join([string(name_parts[1]), "class.instructors"], "+"), ext])]))
        save(data.roster,       joinpath([dir, join([join([string(name_parts[1]), "class.roster"], "+"), ext])]))
        save(data,              joinpath([dir, join([join([string(name_parts[1]), "class"], "+"), ext])]), ["course", "instructors", "students", "roster"])
    end
    return nothing
end

function save(data::Submission, path)
    dir, base, name, ext = dirbasenameextname(path)
    name_parts = split(name, "+")
    if length(name_parts) == 2
        save(data.assignment,   joinpath([dir, join([join([string(name_parts[1]), join(["submission.assignment", string(name_parts[2])], ".")], "+"), ext])]))
        save(data.submitted,     joinpath([dir, join([join([string(name_parts[1]), join(["submission.datetime", string(name_parts[2])], ".")], "+"), ext])]))
        save(data.score,        joinpath([dir, join([join([string(name_parts[1]), join(["submission.score", string(name_parts[2])], ".")], "+"), ext])]))
    else
        save(data.assignment,   joinpath([dir, join([join([string(name_parts[1]), "submission.assignment"], "+"), ext])]))
        save(data.submitted,     joinpath([dir, join([join([string(name_parts[1]), "submission.datetime"], "+"), ext])]))
        save(data.score,        joinpath([dir, join([join([string(name_parts[1]), "submission.score"], "+"), ext])]))
    end
    return nothing
end

function save(data::Grade, path)
    dir, base, name, ext = dirbasenameextname(path)
    name_parts = split(name, "+")
    if length(name_parts) == 2
        save(data.student,      joinpath([dir, join([join([string(name_parts[1]), join(["grade.student", string(name_parts[2])], ".")], "+"), ext])]))
        save(data.assignment,   joinpath([dir, join([join([string(name_parts[1]), join(["grade.assignment", string(name_parts[2])], ".")], "+"), ext])]))
        save(data.submission,   joinpath([dir, join([join([string(name_parts[1]), join(["grade.submission", string(name_parts[2])], ".")], "+"), ext])]))
    else
        save(data.student,      joinpath([dir, join([join([string(name_parts[1]), "grade.student"], "+"), ext])]))
        save(data.assignment,   joinpath([dir, join([join([string(name_parts[1]), "grade.assignment"], "+"), ext])]))
        save(data.submission,   joinpath([dir, join([join([string(name_parts[1]), "grade.submission"], "+"), ext])]))
    end
    return nothing
end

function save(data::Gradebook{Class}, path)
    df = data.data
    sort!(df, [:name_last, :name_first])
    save(df, path)
    return nothing
end
function save(data::Gradebook{Student}, path)
    save(data.data, path)
    return nothing
end



function _fetch_class_data(class::Class, data::String)
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

fetch_class_gradebook(class::Class) = _fetch_class_data(class, "Gradebook")
# fetch_class_attendance(class::Class) = _fetch_class_data(class, "Attendance")

# function fetch_student_gradebook(student::Student, class::Class)
# end
