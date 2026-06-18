export VALID_DATE_FORMATS, DATE_FORMAT
export INSTITUTION, set_institution, get_institution
export INSTITUTION_EMAILDOMAIN, set_institution_emaildomain, get_institution_emaildomain
export COURSE_GRADESCALE, set_course_gradescale, get_course_gradescale
export COURSE_POINTSCALE, set_course_pointscale, get_course_pointscale
export ATTENDANCE_LIMIT, set_attendance_limit, get_attendance_limit
export ATTENDANCE_PENALTY, set_attendance_penalty, get_attendance_penalty
export STRING_MATCH_THRESHOLD, set_string_match_threshold, get_string_match_threshold

using Preferences

# TODO: can define Course or Class as preferences?
const VALID_DATE_FORMATS = (:MMDDYYYY, :DDMMYYYY)
const DATE_FORMAT = begin
    @warn "Loading default `DATE_FORMAT` as `:MMDDYYYY`..."
    @load_preference("DATE_FORMAT", :MMDDYYYY)
end
const INSTITUTION = @load_preference("INSTITUTION")
const INSTITUTION_EMAILDOMAIN = @load_preference("INSTITUTION_EMAILDOMAIN")
const COURSE_GRADESCALE = @load_preference("COURSE_GRADESCALE", 4)
const COURSE_POINTSCALE = @load_preference("COURSE_POINTSCALE", 1000)
const ATTENDANCE_LIMIT = @load_preference("ATTENDANCE_LIMIT", 4)
const ATTENDANCE_PENALTY = @load_preference("ATTENDANCE_PENALTY", 50)
const STRING_MATCH_THRESHOLD = @load_preference("STRING_MATCH_THRESHOLD", 0.2)

function set_date_format(fmt::Symbol)
    if !(fmt in VALID_DATE_FORMATS)
        @error("Invalid `DATE_FORMAT`. Please choose from: $(join(VALID_DATE_FORMATS, ", "))")
    end
    @set_preferences!("DATE_FORMAT" => fmt)
    @info("New `DATE_FORMAT` set; restart your Julia session for this change to take effect!")
end

get_date_format() = @load_preference("DATE_FORMAT")

function set_institution(org::String)
    @set_preferences!("INSTITUTION" => org)
    @info("New `INSTITUTION` set; restart your Julia session for this change to take effect!")
end

get_institution() = @load_preference("INSTITUTION")

function set_institution_emaildomain(domain::String)
    @set_preferences!("INSTITUTION_EMAILDOMAIN" => domain)
    @info("New `INSTITUTION_EMAILDOMAIN` set; restart your Julia session for this change to take effect!")
end

get_institution_emaildomain() = @load_preference("INSTITUTION_EMAILDOMAIN")

function set_course_gradescale(scale::Integer)
    @set_preferences!("COURSE_GRADESCALE" => scale)
    @info("New `COURSE_GRADESCALE` set; restart your Julia session for this change to take effect!")
end

get_course_gradescale() = @load_preference("COURSE_GRADESCALE")

function set_course_pointscale(scale::Integer)
    @set_preferences!("COURSE_POINTSCALE" => scale)
    @info("New `COURSE_POINTSCALE` set; restart your Julia session for this change to take effect!")
end

get_course_pointscale() = @load_preference("COURSE_POINTSCALE")

function set_attendance_limit(limit::Integer)
    @set_preferences!("ATTENDANCE_LIMIT" => limit)
    @info("New `ATTENDANCE_LIMIT` set; restart your Julia session for this change to take effect!")
end

get_attendance_limit() = @load_preference("ATTENDANCE_LIMIT")

function set_attendance_penalty(penalty::Integer)
    @set_preferences!("ATTENDANCE_PENALTY" => penalty)
    @info("New `ATTENDANCE_PENALTY` set; restart your Julia session for this change to take effect!")
end

get_attendance_penalty() = @load_preference("ATTENDANCE_PENALTY")

function set_string_match_threshold(threshold::Float64)
    @set_preferences!("STRING_MATCH_THRESHOLD" => threshold)
    @info("New `STRING_MATCH_THRESHOLD` set; restart your Julia session for this change to take effect!")
end

get_string_match_threshold() = @load_preference("STRING_MATCH_THRESHOLD")
