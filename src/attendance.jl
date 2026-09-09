export AttendanceStatus, AttendanceRecord, ispresent, isabsent, isexcused, islate, istardy
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

isattendance(x::AttendanceRecord)   = true
ispresent(r)                        = false
ispresent(r::AttendanceStatus)      = r == Present
ispresent(r::AttendanceRecord)      = ispresent(r.status)
isabsent(r)                         = false
isabsent(r::AttendanceStatus)       = r == Absent
isabsent(r::AttendanceRecord)       = isabsent(r.status)
isexcused(r)                        = false
isexcused(r::AttendanceStatus)      = r == Excused
isexcused(r::AttendanceRecord)      = isexcused(r.status)
islate(r)                           = false
islate(r::AttendanceStatus)         = r == Late
islate(r::AttendanceRecord)         = islate(r.status)
istardy(r)                          = false
istardy(r::AttendanceStatus)        = r == Tardy
istardy(r::AttendanceRecord)        = istardy(r.status)

function record!(gb, student, lecture, record)
    if isactive(student) && (isnothing(student.final_grade) || student.final_grade ∉ [FN, W, I])
        i = gb.class.roster.by_id[student.person.id]
        gb.raw[i, lecture.codename] = record
        t = count(isabsent, gb.raw[i, :][filter(j->isassigned(gb.raw[!, j], i), length(gb.class.course.assignments) .+ (1:length(gb.class.lectures)))]) # + count(==(0), Matrix(att.raw_score[occursin.(key, att.raw_score[!, "Email"]), :]))
        p = Point(isabsent(record) && t > (ATTENDANCE_LIMIT + get_attendance_modifier(student)) ? ATTENDANCE_PENALTY : 0.0)
        gb.penalty[i, lecture.codename] = p
        gb.total[i, lecture.codename] = record
    end
    return nothing
end

"""
Records quality of attendance for a class lecture (`date_lecture`) entered on `date_stamp`.

`marks` is magically parsed for combinations of `AttendanceStatus`, students, and comments.

## Example
```
attendance_record!(gb, "Jun. 19, 2026", "Jun. 20, 2026", [NoRecord])
attendance_record!(gb, "2026-06-22", Date(2026, 06, 15), [
    (Excused, "Canceled due to snow")])
attendance_record!(gb, Date("2026-06-24"), Date("2026-06-25"), [
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
    for mark ∈ marks
        if length(mark) <= 2 && any(x->isa(x, AttendanceStatus), mark) && !(any(x->isa(try
                    get_student(x, gb; threshold=threshold)
                catch
                    false
                end, Student), mark))
            which_record_idx = findfirst(x->isa(x, AttendanceStatus), mark)
            record = length(mark) == 2 ? AttendanceRecord(mark[which_record_idx], date_stamp, mark[which_record_idx == 1 ? 2 : 1]) : AttendanceRecord(only(mark), date_stamp)
            map(s->record!(gb, s, lecture, record), gb.class.roster.students)
        elseif length(mark) <= 3 && any(x->isa(x, AttendanceStatus), mark) && any(x->isa(try
                    get_student(x, gb; threshold=threshold)
                catch
                    false
                end, Student), mark)
            which_record_idx = findfirst(x->isa(x, AttendanceStatus), mark)
            which_student_idx = findfirst(x->isa(get_student(x, gb; threshold=threshold), Student), mark)
            record = if length(mark) == 3
                which_comment_idx = findfirst(x->x ∉ [which_record_idx, which_student_idx], [1, 2, 3])
                AttendanceRecord(mark[which_record_idx], date_stamp, mark[which_comment_idx])
            elseif length(mark) == 2
                AttendanceRecord(mark[which_record_idx], date_stamp)
            else
                error("Could not parse mark for which is student, stamp, or comment: $mark")
            end
            record!(gb, get_student(mark[which_student_idx], gb), lecture, record)
        else
            error("Could not parse mark for which is student, stamp, or comment: $mark")
        end
    end
    return nothing
end

"""
Maps string input to `AttendanceStatus` value.

## Example
```
function attendance_status_map_from_string(x::AbstractString)
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

function resolve_column_date_pairs(df::DataFrame, column_date_pairs::Vector{Pair{String, Date}}, row_first::Int)
    resolved = Pair{Int, Date}[]
    col_names = lowercase.(strip.(string.(names(df))))

    for (col_label, lecture_date) in column_date_pairs
        key = lowercase(strip(col_label))
        matches = findall(==(key), col_names)

        if !isempty(matches)
            push!(resolved, first(matches) => lecture_date)
            continue
        end

        # Fall back to scanning nearby rows for the label text itself.
        found = false
        for r in max(1, row_first-1):min(nrow(df), row_first+1)
            for j in 1:ncol(df)
                v = string(df[r, j])
                if lowercase(strip(v)) == key
                    push!(resolved, j => lecture_date)
                    found = true
                    break
                end
            end
            found && break
        end

        if !found
            error("Could not resolve column name $(col_label) to a dataframe column or nearby row label.")
        end
    end

    return resolved
end

"""
Records on date of entry (`date_stamp`) quality of attendance from a file matching `regex` within `dir`.

## Warning
If using this method, make sure to implement `attendance_status_map_from_string(x::AbstractString)`.
"""
function attendance_record!(gb::Gradebook, date_stamp::Union{Date, String}, regex::Regex, dir::String, column_date_pairs=Vector{Pair{String, Date}}(); row_date::Int=1, row_first::Int=2, use_last=true, threshold=STRING_MATCH_THRESHOLD, kwargs...)
    lecture_dates = map(x->Date(x.due), gb.class.lectures)
    course_exports = sort(filter(x->occursin(regex, basename(x)), readdir(dir; join=true)))
    for course_export in course_exports[use_last ? [end] : begin:end]
        submissions_df = CSV.read(course_export, DataFrame; kwargs...)

        # Explicit column-date mapping wins.
        if !isempty(column_date_pairs)
            resolved_pairs = resolve_column_date_pairs(submissions_df, column_date_pairs, row_first)
            # @show resolved_pairs

            # find the student-id column once
            first_column, first_row = 0, 0
            for j in 1:ncol(submissions_df)
                col_vals = map(x -> ismissing(x) ? "" : String(x), submissions_df[!, j])
                nonempty = findall(!isempty, col_vals)
                if isempty(nonempty) || length(nonempty) <= (length(gb.class.roster.students) ÷ 2)
                    continue
                end
                valid = map(nonempty) do i
                    try
                        get_student(col_vals[i], gb.class.roster; threshold=threshold)
                        true
                    catch
                        false
                    end
                end
                if all(valid)
                    first_column, first_row = j, first(nonempty)
                    break
                end
            end
            # @show first_column, submissions_df[first_row:end, first_column]

            if first_column == 0
                error("Could not find a valid student ID column.")
            end

            for (col_idx, lecture_date) in resolved_pairs
                lecture = gb.class.lectures[findlast(x -> x <= lecture_date, map(y -> Date(y.due), gb.class.lectures))]
                # @show col_idx, lecture_date, lecture.codename
                for i in first_row:nrow(submissions_df)
                    student_val = submissions_df[i, first_column]
                    status_val = submissions_df[i, col_idx]
                    # @show i, student_val, status_val

                    if ismissing(student_val) || isempty(strip(String(student_val)))
                        continue
                    end
                    try
                        student = get_student(String(student_val), gb.class.roster; threshold=threshold)
                        status = attendance_status_map_from_string(string(status_val))
                        record!(gb, student, lecture, AttendanceRecord(status, parse_date(date_stamp), "3rd Party"))
                    catch
                        continue
                    end
                end
            end
            # continue
        end

        # fallback old behavior: infer from date row + regex
        attendance_records_idx = findall(x->any(x .== String.(findall(x->!ismissing(x) && isa(parse_datetime(string_sanitize(x)), AbstractDateTime), submissions_df[row_date, :]))), names(submissions_df))
        attendance_records = map(x->parse_datetime(string_sanitize(x)), collect(submissions_df[row_date, attendance_records_idx]))
        first_column, first_row = 0, 0
        for j ∈ 1:(first(attendance_records_idx)-1)
            submissions_df[!, j] = convert.(String, map(x -> ismissing(x) ? "" : String(x), submissions_df[!, j]))
            if first_column == 0
                for (i, val) ∈ enumerate(submissions_df[!, j])
                    try
                        get_student(val, gb; threshold=threshold)
                        first_row = i
                        break
                    catch
                    end
                end
            end
            valid_student_vals = map(first_row:length(submissions_df[!, j])) do i
                try
                    get_student(submissions_df[i, j], gb.class.roster; threshold=threshold)
                    true
                catch
                    false
                end
            end
            if all(valid_student_vals)
                first_column = j
                break
            end
        end
        if first_column == 0
            error("Could not find a column whose non-empty values all identify students in the roster.")
        end
        for i ∈ attendance_records_idx
            submissions_df[!, i] = convert.(String, submissions_df[!, i])
        end
        attendance_records_idx .-= first_column - 1
        submissions_df = submissions_df[first_row:end, first_column:end]

        for (i, attendance_record) ∈ zip(attendance_records_idx, attendance_records)
            if !isnothing(findfirst(Date(attendance_record) .== lecture_dates))
                marks = map(x->(x[1], attendance_status_map_from_string(x[2]), "3rd Party"), eachrow(submissions_df[!, [1, i]]))
                attendance_record!(gb, date_stamp, Date(attendance_record), marks; threshold=threshold)
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
    for (i, row) ∈ enumerate(eachrow(df))
        for j ∈ 1:1:ncol(df)
            t = count(isabsent, row[filter(k->isassigned(gb.raw[!, length(gb.class.course.assignments)+k], i), 1:j)]) # + count(==(0), collect(row)[begin:j])
            p = Point(isassigned(df[!, j], i) && isabsent(row[j]) && t > (ATTENDANCE_LIMIT + get_attendance_modifier(gb.class.roster.students[i])) ? ATTENDANCE_PENALTY : 0.0)
            gb.penalty[i, gb.class.lectures[j].codename] = p
        end
    end
    return nothing
end

"Convenience function to ensure attendance penalties are current."
attendance_sync!(gb::Gradebook) = attendance_update!(gb)
