export VALID_DATE_FORMATS, DATE_FORMAT
export INSTITUTION, set_institution, get_institution
export INSTITUTION_EMAILDOMAIN, set_institution_emaildomain, get_institution_emaildomain
export COURSE_QUALITYPOINTS_A, set_course_qualitypoints_a, get_course_qualitypoints_a
export COURSE_POINT_SYSTEM, set_course_pointsystem, get_course_pointsystem
export COURSE_POINT_SCALE, set_course_pointscale, get_course_pointscale
export COURSE_POINT_SCALE_PLUSMINUS, set_course_pointscale_plusminus, get_course_pointscale_plset_course_pointscale_plusminus
export ATTENDANCE_LIMIT, set_attendance_limit, get_attendance_limit
export ATTENDANCE_PENALTY, set_attendance_penalty, get_attendance_penalty
export STRING_MATCH_THRESHOLD, set_string_match_threshold, get_string_match_threshold



using Preferences



@enum VALID_DATE_FORMATS MMDDYYYY DDMMYYYY

"Regional preference for whether month (`MMDDYYYY`) or day (`DDMMYYYY`) is written first in a date string."
const DATE_FORMAT = begin
    @warn "Loading default `DATE_FORMAT` as `MMDDYYYY`..."
    @load_preference("DATE_FORMAT", MMDDYYYY)
end

"Institution name: e.g., \"Liberty University\" or \"Massachussettes Institute of Technology\"."
const INSTITUTION = @load_preference("INSTITUTION")

"Email domain: e.g., `\"liberty.edu\" or \"mit.edu\". This helps if searching by username instead of full email addresses."
const INSTITUTION_EMAILDOMAIN = @load_preference("INSTITUTION_EMAILDOMAIN")

"Credit hours of course."
const COURSE_CREDITS = @load_preference("COURSE_CREDITS", 3)

"Quality points of an \"A\" for calculating weighted GPA."
const COURSE_QUALITYPOINTS_A = @load_preference("COURSE_QUALITYPOINTS_A", 4)

"Quality points of an \"A+\" for calculating weighted GPA."
const COURSE_QUALITYPOINTS_APLUS = @load_preference("COURSE_QUALITYPOINTS_APLUS", COURSE_QUALITYPOINTS_A)

"Quality point +/- devation for calculating weighted GPA."
const COURSE_QUALITYPOINTS_PLUSMINUS = @load_preference("COURSE_QUALITYPOINTS_PLUSMINUS", 0)

"Total number of points a student can earn."
const COURSE_POINT_SYSTEM = @load_preference("COURSE_POINT_SYSTEM", 1000)

"Point division between letter grades."
const COURSE_POINT_SCALE = @load_preference("COURSE_POINT_SCALE", 100)

"Point +/- deviation between letter grades."
const COURSE_POINT_SCALE_PLUSMINUS = @load_preference("COURSE_POINT_SCALE_PLUSMINUS", 0)

"How many absences are allowed before penalties are applied."
const ATTENDANCE_LIMIT = @load_preference("ATTENDANCE_LIMIT", 4)

"Point deduction for so many absences exceeding `ATTENDANCE_LIMIT`."
const ATTENDANCE_PENALTY = @load_preference("ATTENDANCE_PENALTY", 50)

"Threshold for Levenshtein string matching."
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

function set_course_credits(credits::Integer)
    @set_preferences!("COURSE_CREDITS" => credits)
    @info("New `COURSE_CREDITS` set; restart your Julia session for this change to take effect!")
end

get_course_credits() = @load_preference("COURSE_CREDITS")

function set_course_qualitypoints_a(scale::Integer)
    @set_preferences!("COURSE_QUALITYPOINTS_A" => scale)
    @info("New `COURSE_QUALITYPOINTS_A` set; restart your Julia session for this change to take effect!")
end

get_course_qualitypoints_a() = @load_preference("COURSE_QUALITYPOINTS_A")

function set_course_qualitypoints_aplus(scale::Real)
    @set_preferences!("COURSE_QUALITYPOINTS_APLUS" => scale)
    @info("New `COURSE_QUALITYPOINTS_APLUS` set; restart your Julia session for this change to take effect!")
end

get_course_qualitypoints_aplus() = @load_preference("COURSE_QUALITYPOINTS_APLUS")

function set_course_qualitypoints_plusminus(scale::AbstractFloat)
    @set_preferences!("COURSE_QUALITYPOINTS_PLUSMINUS" => scale)
    @info("New `COURSE_QUALITYPOINTS_PLUSMINUS` set; restart your Julia session for this change to take effect!")
end

get_course_qualitypoints_plusminus() = @load_preference("COURSE_QUALITYPOINTS_PLUSMINUS")

function set_course_pointsystem(system::Integer)
    @set_preferences!("COURSE_POINT_SYSTEM" => system)
    @info("New `COURSE_POINT_SYSTEM` set; restart your Julia session for this change to take effect!")
end

get_course_pointsystem() = @load_preference("COURSE_POINT_SYSTEM")

function set_course_pointscale(scale::Integer)
    @set_preferences!("COURSE_POINT_SCALE" => scale)
    @info("New `COURSE_POINT_SCALE` set; restart your Julia session for this change to take effect!")
end

get_course_pointscale() = @load_preference("COURSE_POINT_SCALE")

function set_course_pointscale_plusminus(scale::Integer)
    @set_preferences!("COURSE_POINT_SCALE_PLUSMINUS" => scale)
    @info("New `COURSE_POINT_SCALE_PLUSMINUS` set; restart your Julia session for this change to take effect!")
end

get_course_pointscale_plusminus() = @load_preference("COURSE_POINT_SCALE_PLUSMINUS")

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
