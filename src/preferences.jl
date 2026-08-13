export DATE_FORMAT, set_date_format, get_date_format
export INSTITUTION_NAME, set_institution_name, get_institution_name
export INSTITUTION_EMAILDOMAIN, set_institution_emaildomain, get_institution_emaildomain
export INSTITUTION_IDPREFIX, set_institution_idprefix, get_institution_idprefix
export COURSE_QUALITYPOINTS_A, set_course_qualitypoints_a, get_course_qualitypoints_a
export COURSE_QUALITYPOINTS_APLUS, set_course_qualitypoints_aplus, get_course_qualitypoints_aplus
export COURSE_QUALITYPOINTS_PLUSMINUS, set_course_qualitypoints_plusminus, get_course_qualitypoints_plusminus
export COURSE_POINT_SYSTEM, set_course_point_system, get_course_point_system
export COURSE_POINT_SCALE, set_course_point_scale, get_course_point_scale
export COURSE_POINT_SCALE_PLUSMINUS, set_course_point_scale_plusminus, get_course_point_scale_plusminus
export COURSE_POINT_DECIMALPLACES, set_course_point_decimalplaces, get_course_point_decimalplaces
export ATTENDANCE_LIMIT, set_attendance_limit, get_attendance_limit
export ATTENDANCE_PENALTY, set_attendance_penalty, get_attendance_penalty
export STRING_MATCH_THRESHOLD, set_string_match_threshold, get_string_match_threshold
export DISPLAY_CREDITS_TYPES, auto, point, percent, DISPLAY_CREDITS, set_display_credits, get_display_credits



using Preferences



"Regional preference for whether month or day is written first in a date string by: `\"MMDDYYYY\"` (default) or `\"DDMMYYYY\"`, respectively."
const DATE_FORMAT = @load_preference("DATE_FORMAT", "MMDDYYYY")

function set_date_format(format::String)
    if !(format ∈ ["MMDDYYYY", "DDMMYYYY"])
        @error "Invalid `DATE_FORMAT`. Please choose from: [\"MMDDYYYY\", \"DDMMYYYY\"]"
    end
    @set_preferences!("DATE_FORMAT" => format)
    @info("New `DATE_FORMAT` set; restart your Julia session for this change to take effect!")
end

get_date_format() = @load_preference("DATE_FORMAT")



"Institution name: e.g., \"Liberty University\" or \"Massachussettes Institute of Technology\"."
const INSTITUTION_NAME = @load_preference("INSTITUTION_NAME")

function set_institution_name(org::String)
    @set_preferences!("INSTITUTION_NAME" => org)
    @info("New `INSTITUTION_NAME` set; restart your Julia session for this change to take effect!")
end

get_institution_name() = @load_preference("INSTITUTION_NAME")


"Email domain: e.g., `\"liberty.edu\" or \"mit.edu\". This helps if searching by username instead of full email addresses."
const INSTITUTION_EMAILDOMAIN = @load_preference("INSTITUTION_EMAILDOMAIN")

function set_institution_emaildomain(domain::String)
    @set_preferences!("INSTITUTION_EMAILDOMAIN" => domain)
    @info("New `INSTITUTION_EMAILDOMAIN` set; restart your Julia session for this change to take effect!")
end

get_institution_emaildomain() = @load_preference("INSTITUTION_EMAILDOMAIN")


"Student ID prefix: e.g., `\"LU\"` or `\"MIT\"`. This helps if searching by username instead of full email addresses."
const INSTITUTION_IDPREFIX = @load_preference("INSTITUTION_IDPREFIX")

function set_institution_idprefix(prefix::String)
    @set_preferences!("INSTITUTION_IDPREFIX" => prefix)
    @info("New `INSTITUTION_IDPREFIX` set; restart your Julia session for this change to take effect!")
end

get_institution_idprefix() = @load_preference("INSTITUTION_IDPREFIX")



"Credit hours of course."
const COURSE_CREDITS = @load_preference("COURSE_CREDITS", 3)

function set_course_credits(credits::Integer)
    @set_preferences!("COURSE_CREDITS" => credits)
    @info("New `COURSE_CREDITS` set; restart your Julia session for this change to take effect!")
end

get_course_credits() = @load_preference("COURSE_CREDITS")


"Quality points of an \"A\" for calculating weighted GPA."
const COURSE_QUALITYPOINTS_A = @load_preference("COURSE_QUALITYPOINTS_A", 4)

function set_course_qualitypoints_a(scale::Integer)
    @set_preferences!("COURSE_QUALITYPOINTS_A" => scale)
    @info("New `COURSE_QUALITYPOINTS_A` set; restart your Julia session for this change to take effect!")
end

get_course_qualitypoints_a() = @load_preference("COURSE_QUALITYPOINTS_A")


"Quality points of an \"A+\" for calculating weighted GPA."
const COURSE_QUALITYPOINTS_APLUS = @load_preference("COURSE_QUALITYPOINTS_APLUS", COURSE_QUALITYPOINTS_A)

function set_course_qualitypoints_aplus(scale::Real)
    @set_preferences!("COURSE_QUALITYPOINTS_APLUS" => scale)
    @info("New `COURSE_QUALITYPOINTS_APLUS` set; restart your Julia session for this change to take effect!")
end

get_course_qualitypoints_aplus() = @load_preference("COURSE_QUALITYPOINTS_APLUS")


"Quality point +/- devation for calculating weighted GPA."
const COURSE_QUALITYPOINTS_PLUSMINUS = @load_preference("COURSE_QUALITYPOINTS_PLUSMINUS", 0)

function set_course_qualitypoints_plusminus(scale::AbstractFloat)
    @set_preferences!("COURSE_QUALITYPOINTS_PLUSMINUS" => scale)
    @info("New `COURSE_QUALITYPOINTS_PLUSMINUS` set; restart your Julia session for this change to take effect!")
end

get_course_qualitypoints_plusminus() = @load_preference("COURSE_QUALITYPOINTS_PLUSMINUS")


"Total number of points a student can earn."
const COURSE_POINT_SYSTEM = @load_preference("COURSE_POINT_SYSTEM", 1000)

function set_course_point_system(system::Integer)
    @set_preferences!("COURSE_POINT_SYSTEM" => system)
    @info("New `COURSE_POINT_SYSTEM` set; restart your Julia session for this change to take effect!")
end

get_course_point_system() = @load_preference("COURSE_POINT_SYSTEM")


"Point division between letter grades."
const COURSE_POINT_SCALE = @load_preference("COURSE_POINT_SCALE", 100)

function set_course_point_scale(scale::Integer)
    @set_preferences!("COURSE_POINT_SCALE" => scale)
    @info("New `COURSE_POINT_SCALE` set; restart your Julia session for this change to take effect!")
end

get_course_point_scale() = @load_preference("COURSE_POINT_SCALE")


"Point +/- deviation between letter grades."
const COURSE_POINT_SCALE_PLUSMINUS = @load_preference("COURSE_POINT_SCALE_PLUSMINUS", 0)

function set_course_point_scale_plusminus(scale::Integer)
    @set_preferences!("COURSE_POINT_SCALE_PLUSMINUS" => scale)
    @info("New `COURSE_POINT_SCALE_PLUSMINUS` set; restart your Julia session for this change to take effect!")
end

get_course_point_scale_plusminus() = @load_preference("COURSE_POINT_SCALE_PLUSMINUS")


"Number of decimal places to display."
const COURSE_POINT_DECIMALPLACES = @load_preference("COURSE_POINT_DECIMALPLACES", 2)

function set_course_point_decimalplaces(scale::Integer)
    @set_preferences!("COURSE_POINT_DECIMALPLACES" => scale)
    @info("New `COURSE_POINT_DECIMALPLACES` set; restart your Julia session for this change to take effect!")
end

get_course_point_decimalplaces() = @load_preference("COURSE_POINT_DECIMALPLACES")



"How many absences are allowed before penalties are applied."
const ATTENDANCE_LIMIT = @load_preference("ATTENDANCE_LIMIT", 4)

function set_attendance_limit(limit::Integer)
    @set_preferences!("ATTENDANCE_LIMIT" => limit)
    @info("New `ATTENDANCE_LIMIT` set; restart your Julia session for this change to take effect!")
end

get_attendance_limit() = @load_preference("ATTENDANCE_LIMIT")


"Point deduction for so many absences exceeding `ATTENDANCE_LIMIT`."
const ATTENDANCE_PENALTY = @load_preference("ATTENDANCE_PENALTY", 50)

function set_attendance_penalty(penalty::Integer)
    @set_preferences!("ATTENDANCE_PENALTY" => penalty)
    @info("New `ATTENDANCE_PENALTY` set; restart your Julia session for this change to take effect!")
end

get_attendance_penalty() = @load_preference("ATTENDANCE_PENALTY")



"Threshold for Levenshtein string matching."
const STRING_MATCH_THRESHOLD = @load_preference("STRING_MATCH_THRESHOLD", 0.2)

function set_string_match_threshold(threshold::Float64)
    @set_preferences!("STRING_MATCH_THRESHOLD" => threshold)
    @info("New `STRING_MATCH_THRESHOLD` set; restart your Julia session for this change to take effect!")
end

get_string_match_threshold() = @load_preference("STRING_MATCH_THRESHOLD")



@enum DISPLAY_CREDITS_TYPES auto point percent


"Whether to display credit earned as `Point` by `:point`, `Percent` by `:percent`, or let the system decide with `:auto` (default)."
const DISPLAY_CREDITS = @load_preference("DISPLAY_CREDITS", :auto)

function set_display_credits(display::Symbol)
    if !(display ∈ Symbol.(instances(DISPLAY_CREDITS_TYPES)))
        @error "Invalid `DISPLAY_CREDITS`. Please choose from symbols:" DISPLAY_CREDITS_TYPES
    end
    @set_preferences!("DISPLAY_CREDITS" => string(display))
    @info("New `DISPLAY_CREDITS` set; restart your Julia session for this change to take effect!")
end

get_display_credits() = @load_preference("DISPLAY_CREDITS")
