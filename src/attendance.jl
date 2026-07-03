export AttendanceStatus, AttendanceRecord, is_present, is_absent, is_excused, is_late, is_tardy
public record!
export attendance_status_map_from_string, attendance_record!, attendance_update!, attendance_sync!



"Semantic options for how much attended of a class lecture."
@enum AttendanceStatus begin
    Present
    Absent
    Excused
    Late
    Tardy
    NoRecord
end

"Records datetime stamp of attendance status[ with comments]."
struct AttendanceRecord
    status::AttendanceStatus
    stamp::DateTime
    comment::String
    AttendanceRecord(status, stamp, comment) = new(status, (isa(stamp, DateTime) ? stamp : (isa(stamp, Date) ? DateTime(stamp, MIDNIGHT) : error("Got unrecognized stamp type: $stamp, T=$(typeof(stamp))"))), comment)
end
AttendanceRecord(status::AttendanceStatus, stamp::Union{DateTime, Date}; comment::String="") = AttendanceRecord(status, stamp, comment)

is_present(r::AttendanceRecord) = r.status == Present
is_absent(r::AttendanceRecord)  = r.status == Absent
is_excused(r::AttendanceRecord) = r.status == Excused
is_late(r::AttendanceRecord) = r.status == Late
is_tardy(r::AttendanceRecord) = r.status == Tardy

function record!(gb, student, lecture, record)
    if student.enrollment_status == Active && (isnothing(student.final_grade) || student.final_grade ∉ [FN, W, I])
        i = gb.class.roster.index.by_id[student.person.id]
        gb.raw[i, lecture.codename] = record
        t = count(==(Absent), gb.raw[i, :][filter(j->isassigned(gb.raw[!, j], i), length(gb.class.course.assignments) .+ (1:length(gb.class.lectures)))]) # + count(==(0), Matrix(att.raw_score[occursin.(key, att.raw_score[!, "Email"]), :]))
        p = Point(t <= ATTENDANCE_LIMIT ? 0 : ((t - ATTENDANCE_LIMIT) * ATTENDANCE_PENALTY))
        gb.penalty[i, lecture.codename] = p
        gb.total[i, lecture.codename] = record
    end
end

"""
Records quality of attendance for a class lecture (`date_lecture`) entered on `date_stamp`.

`marks` is magically parsed for combinations of `AttendanceStatus`, students, and comments.

## Example
```
record_attendance!(gb, "Jun. 19, 2026", "Jun. 20, 2026", [NoRecord])
record_attendance!(gb, "2026-06-22", Date(2026, 06, 15), [
    (Excused, "Canceled due to snow")])
record_attendance!(gb, Date("2026-06-24"), Date("2026-06-25"), [
    ("alice@example.edu", Late, "Blew a tire"),
    (Present, "bob@example.edu", "Forgot to entire attendance code"),
    (Absent, "cole@example.edu"),
])
```
"""
function attendance_record!(gb::Gradebook, date_stamp::Union{Date, String}, date_lecture::Union{Date, String}, marks::Vector{<:Any}; threshold=STRING_MATCH_THRESHOLD)
    date_stamp = parse_date(date_stamp)
    date_lecture = parse_date(date_lecture)
    lecture = gb.class.lectures[findlast(x->x<=date_lecture, map(y->Date(y.due), gb.class.lectures))]
    # grades_post!(gb, map(x->grade(x[1], gb.class.roster, lecture, date_lecture, length(x) == 3 ? AttendanceRecord(x[2], date_stamp, x[3]) : AttendanceRecord(x[2], date_stamp))), marks)
    # attendance_idx = filter(!isnothing, indexin(assignments, filter(x->x.category !== :attendance, gb.class.course.assignments)))
    for mark in marks
        if length(mark) <= 2 && any(x->isa(x, AttendanceStatus), mark) && !(any(x->isa(get_student(x, gb.class.roster; threshold=threshold), Student), mark))
            which_record_idx = findfirst(x->isa(x, AttendanceStatus), mark)
            record = length(mark) == 2 ? AttendanceRecord(mark[which_record_idx], date_stamp, mark[which_record_idx == 1 ? 2 : 1]) : AttendanceRecord(only(mark), date_stamp)
            record!.(gb, gb.class.roster.students, record)
        elseif length(mark) <= 3 && any(x->isa(x, AttendanceStatus), mark) && any(x->isa(get_student(x, gb.class.roster; threshold=threshold), Student), mark)
            which_record_idx = findfirst(x->isa(x, AttendanceStatus), mark)
            which_student_idx = findfirst(x->isa(get_student(x, gb.class.roster; threshold=threshold), Student), mark)
            record = if length(mark) == 3
                which_comment_idx = findfirst(x->x ∉ [which_record_idx, which_student_idx], [1, 2, 3])
                AttendanceRecord(mark[which_record_idx], date_stamp, mark[which_comment_idx])
            elseif length(mark) == 2
                AttendanceRecord(mark[which_record_idx], date_stamp)
            else
                error("foo")
            end
            record!(gb, get_student(mark[which_student_idx], gb.class.roster), lecture, record)
        else
            error("bar")
        end
    end
    return nothing
end

"""
Maps string input to `AttendanceStatus` value.

## Example
```
function attendance_status_from_string(x::AbstractString)
    s = lowercase(strip(x))
    return if s == "present"
        Present
    elseif s == "absent"
        Absent
    elseif s == "excused"
        Excused
    elseif s == "late"
        Late
    elseif s == "tardy"
        Tardy
    else
        missing
    end
end
```
"""
attendance_status_map_from_string(x::AbstractString)::AttendanceStatus = error("Attendance status map not yet implemented for `AbstractString`")

"""
Records on date of entry (`date_stamp`) quality of attendance from a file matching `regex` within `dir`.

## Warning
If using this method, make sure to implement `attendance_status_map_from_string(x::AbstractString)`.
"""
function attendance_record!(gb::Gradebook, date_stamp::Union{Date, String}, regex::Regex, dir::String; threshold=STRING_MATCH_THRESHOLD)
    lecture_dates = map(x->Date(x.due), gb.class.lectures)
    for course_export in filter(x->occursin(regex, basename(x)), readdir(dir; join=true))
        # @show basename(course_export)
        submissions_df = CSV.read(course_export, DataFrame)
        attendance_records_idx = findall(x->isa(parse_datetime(string_sanitize(x)), AbstractDateTime), names(submissions_df))
        attendance_records = map(x->parse_datetime(string_sanitize(x)), names(submissions_df)[attendance_records_idx])
        # submissions_df = submissions_df[!, names(submissions_df)[vcat(1:(first(attendance_records_idx)-1), attendance_records_idx)]]
        # dates = map(x->x[1:findfirst('T', x)-1], collect(submissions_df[1, :])[2:end][findall(x->(length(x)==25 && occursin('T', x)), collect(submissions_df[1, :])[2:end])])
        # submissions_df = DataFrame(Matrix(submissions_df)[findfirst(!ismissing, submissions_df[!, "Email"]):end, begin:end-(length(collect(submissions_df[1, :])[2:end]) - length(dates))], ["Email", dates...])
        first_column, first_row = 0, 0
        for i in 1:(first(attendance_records_idx)-1)
            submissions_df[!, i] = convert.(String, submissions_df[!, i])
            if first_column == 0
                for (j, val) in enumerate(submissions_df[!, i])
                    try
                        get_student(val, gb.class.roster; threshold=threshold)
                    catch
                    else
                        first_column, first_row = i, j
                        break
                    end
                end
            end
        end
        for i in attendance_records_idx
            # submissions_df[!, i] = convert.(AttendanceStatus, attendance_status_map_from_string.(submissions_df[!, i]))
            submissions_df[!, i] = convert.(String, submissions_df[!, i])
        end
        # submissions_df[!, 2] = convert.(Points, (map(x->ismissing(x) ? 0.0 : x, submissions_df[!, 2])))
        # select!(submissions_df, ["Email", sort(names(submissions_df)[2:end])...])

        for (i, attendance_record) in zip(attendance_records_idx, attendance_records)
            if !isnothing(findfirst(attendance_record .== lecture_dates))
                marks = map(x->(x[1], attendance_status_map_from_string(x[2]), "3rd Party"), submissions_df[!, i])
                attendance_record!(gb, date_stamp, attendance_record, marks; threshold=threshold)
            else
                error("Attendance record date ($attendance_record) not found among lecture dates: $lecture_dates")
            end
        end
    end
    return nothing
end

"Calculates number of `Absent` for each student and records penalties."
function attendance_update!(gb::Gradebook)
    df = select(gb.raw, map(x->x.codename, gb.class.lectures))
    for (i, row) in enumerate(eachrow(df))
        for j in 1:1:ncol(df)
            # t = count(==(Absent), gb.raw[i, :][filter(j->isassigned(gb.raw[!, j], i), length(gb.class.course.assignments) .+ (1:length(gb.class.lectures)))]) # + count(==(0), Matrix(att.raw_score[occursin.(key, att.raw_score[!, "Email"]), :]))
            t = count(==(Absent), row[filter(k->isassigned(gb.raw[!, length(gb.class.course.assignments)+k], i), 1:j)]) # + count(==(0), collect(row)[begin:j])
            p = Point(t <= ATTENDANCE_LIMIT ? 0.0 : ATTENDANCE_PENALTY)
            gb.penalty[i, gb.class.lectures[j].codename] = p
        end
    end
    return nothing
end

"Convenience function to ensure attendance penalties are current."
attendance_sync!(gb::Gradebook) = attendance_update!(gb)
