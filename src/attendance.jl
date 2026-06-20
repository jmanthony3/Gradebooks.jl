export attendance_update!, attendance_record!, attendance_sync!



@enum AttendanceStatus begin
    Present
    Absent
    Excused
    Late
    Tardy
    NoRecord
end

struct AttendanceRecord
    status::AttendanceStatus
    comment::String          # Optional explanation
    recorded_at::DateTime    # When you marked it
end

is_present(r::AttendanceRecord) = r.status == Present
is_absent(r::AttendanceRecord)  = r.status == Absent

function attendance_score(records::Vector{AttendanceRecord}, policy::AttendancePolicy)
    total = length(records)
    present_count = count(is_present, records)
    excused_count = count(r -> r.status == Excused, records)
    
    # Apply your policy (free absences, deductions, etc.)
    ...
end

function attendance_record!(gb::Gradebook, regex::Regex, dir::String)
    roster = gb.class.roster
    lectures = gb.class.lectures
    lecture_dates = map(y->Date(y.due), lectures)
    for course_export in readdir(dir; join=true)
        if occursin(regex, basename(course_export))
            # @show basename(course_export)
            submissions_df = CSV.read(course_export, DataFrame)
            submissions_df = submissions_df[!, Cols("Email", 8:2:end-1)]
            dates = map(x->x[1:findfirst('T', x)-1], collect(submissions_df[1, :])[2:end][findall(x->(length(x)==25 && occursin('T', x)), collect(submissions_df[1, :])[2:end])])
            submissions_df = DataFrame(Matrix(submissions_df)[findfirst(!ismissing, submissions_df[!, "Email"]):end, begin:end-(length(collect(submissions_df[1, :])[2:end]) - length(dates))], ["Email", dates...])
            submissions_df[!, 1] = convert.(String, submissions_df[!, 1])
            for i in 2:1:length(names(submissions_df))
                submissions_df[!, i] = convert.(String, submissions_df[!, i])
                submissions_df[!, i] = convert.(Point, (map(x->ismissing(x) ? 0.0 : (x == "--" ? Inf : parse(Float64, x)), submissions_df[!, i])))
            end
            # submissions_df[!, 2] = convert.(Points, (map(x->ismissing(x) ? 0.0 : x, submissions_df[!, 2])))
            select!(submissions_df, ["Email", sort(names(submissions_df)[2:end])...])

            for (i, ld) in enumerate(names(submissions_df)[2:end])
                cl_idx = findfirst(Date(ld) .== lecture_dates)
                cl = "CL$cl_idx"
                if isnothing(cl_idx)
                    @show (i, ld)
                # elseif cl ∈ names(att.total)
                #     @show (i, ld)
                elseif cl ∉ names(gb.total)
                    lecture = lectures[cl_idx]
                    local submissions_dict = Dict{String, Submission}()
                    for row in eachrow(select(submissions_df, ["Email", ld]))
                        submissions_dict[row[1]] = Submission(lecture.due, Score(Point(row[2]), lecture.value), [Evaluation(only(lecture.questions), Grant(Point(row[2])))])
                    end

                    submissions_dict_emails = map(x->string(split(x[1], "@")[1]), collect(pairs(submissions_dict)))
                    # @show submissions_dict_emails
                    roster_emails = map(x->string(split(x.email, "@")[1]), roster)
                    # @show roster_emails
                    emails_possible = intersect(submissions_dict_emails, roster_emails)
                    # @show emails_possible
                    emails_possible_roster_idx = findall(x->x ∈ emails_possible, roster_emails)
                    # @show emails_possible_roster_idx
                    emails_possible_submissions_idx = findall(x->x ∈ emails_possible, submissions_dict_emails)
                    # @show emails_possible_submissions_idx
                    grades = map(x->Grade(only(roster[findall(s->s==string(split(x[1], "@")[1]), roster_emails[emails_possible_roster_idx])]), lecture, x[2]), collect(pairs(submissions_dict))[emails_possible_submissions_idx])
                    grades_post!(gb, grades)
                end
            end
        end
    end
    return nothing
end

function attendance_record!(gb::Gradebook, date::Union{Date, String}, student_mark_pairs::Vararg{Tuple{String, Mark}})
    date = parse_date(date)
    lecture = gb.class.lectures[findlast(x->x<=date, map(y->Date(y.due), gb.class.lectures))]
    grades_post!(gb, map(x->grade(x[1], gb.class.roster, lecture, date, x[2]), student_mark_pairs))
    return nothing
end

function attendance_update!(gb::Gradebook)
    lectures = gb.class.lectures
    df = select(gb.raw, All()=>x->x.category==:attendance)
    for ((i, row), j) in zip(enumerate(eachrow(df)), 1:1:ncol(df))
        t = count(==(-1), collect(row)[begin:j]) + count(==(0), collect(row)[begin:j])
        p = Point(t <= ATTENDANCE_LIMIT ? 0.0 : ATTENDANCE_PENALTY)
        gb.penalty[i, lectures[j].codename] .= p
        gb.total[i, lectures[j].codename] .= p
    end
    return nothing
end

attendance_sync!(gb::Gradebook) = grades_sync!(gb)