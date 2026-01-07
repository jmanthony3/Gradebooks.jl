export fetch_class_gradebook, fetch_student_gradebook
export archive

using CSV
using DataFrames
using Dates

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

function fetch_dict(data::DataType)
    fieldnames = fieldnames(data)
    fieldvalues = getproperty.(data, fieldnames)
    return Dict(zip(fieldnames, fieldvalues))
end

function fetch_dict(data::Grade)
    fieldnames_student = fieldnames(data.student)
    fieldnames_assignment = ["name", "value", "due_datetime"]
    fieldnames_submission = ["submission_datetime", "score_points", "score_percentage", "score_letter"]
    fieldnames = vcat(fieldnames_student, fieldnames_assignment, fieldnames_submission)
    fieldvalues(d, f) = getproperty.(d, f)
    fieldvalues = map((d, f)->fieldvalues(d, f), zip([data.student, data.assignment, data.submission], [fieldnames_student, fieldnames_assignment, fieldnames_submission]))
    return Dict(zip(fieldnames, fieldvalues))
end

function archive_filename(filename)
    datetimestamp = try
        string(split(splitext(filename)[1], "+")[2])
    catch exc
        if isa(exc, BoundsError)
            nothing
        end
    end
    if isnothing(datetimestamp)
        filename_base, filename_ext = splitext(filename)
        filename = filename_base * "+" * safe_datetime_stamp() * filename_ext
    end
    return filename
end

function archive(data::Dict, filename)
    if isempty(splitext(filename)[2])
        filename *= ".json"
    end
    open(archive_filename(filename), "w") do file
        write(file, JSON.json(data, 4))
    end
    return nothing
end

function archive(data::DataFrame, filename)
    if isempty(splitext(filename)[2])
        filename *= ".csv"
    end
    open(archive_filename(filename), "w") do file
        CSV.write(file, data)
    end
    return nothing
end

archive(data::DataType, filename) = archive(fetch_dict(data), filename)
function archive(data::DataType, fieldnames, filename)
    fieldvalues = getproperty.(data, fieldnames)
    archive(Dict(zip(fieldnames, fieldvalues)), filename)
end

archive(data::T, filename) where {T<:AbstractPerson} = archive(data, filename)
function archive(data::Vector{T}, filename) where {T<:AbstractPerson}
    df = DataFrame(first(fetch_dict(data)))
    append!(df, map(d->DataFrame(fetch_dict(d)), data[2:end]))
    sort!(df, [:name_last, :name_first])
    archive(df, filename)
end

archive(data::Course, filename) = archive(data, filename)

function archive(data::Class, filename)
    archive(data.course, filename)
    archive(data, fieldnames(data)[2:5], filename)
    archive(data.instructor, filename)
    archive(data.students, filename)
end

function archive(data::Assignment, filename)
    archive(data, fieldnames(data)[1:3], filename)
end

function archive(data::Vector{Assignment}, filename)
    fieldnames = ["name", "value", "due_datetime"]
    fieldvalues(d) = getproperty.(d, fieldnames)
    df = DataFrame(fieldvalues(first(data)), fieldnames)
    append!(df, map(d->DataFrame(zip(fieldnames, getproperty.(d, fieldnames))), data[2:end]))
    sort!(df, [:due_datetime, :value, :name])
    archive(df, filename)
end

archive(data::Grade, filename) = archive(fetch_dict(data), filename)
function archive(data::Vector{Grade}, filename)
    df = DataFrame(first(fetch_dict(data)))
    append!(df, map(d->DataFrame(fetch_dict(d)), data[2:end]))
    sort!(df, [:due_datetime, :value, :name])
    archive(df, filename)
end

function archive(data::Gradebook{Class}, filename)
    df = data.df
    sort!(df, [:name_last, :name_first])
    archive(df, filename)
end
function archive(data::Gradebook{Student}, filename)
    df = data.df
    sort!(df, [:due_datetime, :value, :name])
    archive(df, filename)
end
