public DAYSOFWEEKSYMBOLCODES, DAYSYMBOLCODEMAP
export MWF, TR
export MIDNIGHT
public frequency2codesymbols
public safe_datetime_stamp, parse_time, parse_date, parse_datetime



using Dates



"Codes for each day of week. (Helpful for internal sorting.)"
const DAYSOFWEEKSYMBOLCODES = [:U, :M, :T, :W, :R, :F, :S]

"Maps input to code representing day of the week."
const DAYSYMBOLCODEMAP = Dict(
    :Sunday=>:U,        "Sunday"=>:U,       "U"=>:U,    'U'=>:U,
    :Monday=>:M,        "Monday"=>:M,       "M"=>:M,    'M'=>:M,
    :Tuesday=>:T,       "Tuesday"=>:T,      "T"=>:T,    'T'=>:T,
    :Wednesday=>:W,     "Wednesday"=>:W,    "W"=>:W,    'W'=>:W,
    :Thursday=>:R,      "Thursday"=>:R,     "R"=>:R,    'R'=>:R,
    :Friday=>:F,        "Friday"=>:F,       "F"=>:F,    'F'=>:F,
    :Saturday=>:S,      "Saturday"=>:S,     "S"=>:S,    'S'=>:S,
)

"Shorthand for class frequency that meets Monday, Wednesday, and Friday."
const MWF = [:M, :W, :F]

"Shorthand for class frequency that meets Tuesday and Thursday."
const TR = [:T, :R]

"Shorthand for 23:59:59.999."
const MIDNIGHT = Time(23, 59, 59, 999)


"Magically maps `input` to vector subset of `DAYSOFWEEKSYMBOLCODES`."
function frequency2codesymbols(input)::Vector{Symbol}
    if isnothing(input)
        return Symbol[]
    elseif isa(input, Symbol)
        if string_2codename(input) == :MWF
            return MWF
        elseif string_2codename(input) == :TR
            return TR
        else
            s = uppercase(string(input))
            days = Symbol[]
            for c in s
                day = get(DAYSYMBOLCODEMAP, c, nothing)
                if isnothing(day)
                    error("Unknown day code $c in :$s")
                else
                    push!(days, day)
                end
            end
            unique!(days)
            return days[filter(!isnothing, indexin(DAYSOFWEEKSYMBOLCODES, days))]
        end
    elseif input isa AbstractVector
        days = Symbol[]
        for item in input
            if isa(item, Symbol) || isa(item, Char) || isa(item, AbstractString)
                key = uppercasefirst(string(item))
                day = get(DAYSYMBOLCODEMAP, key, nothing)
                if isnothing(day)
                    error("Unknown day: $item")
                else
                    push!(days, day)
                end
            # elseif isa(item, Integer)
            #     push!(days, DAYSOFWEEKSYMBOLCODES[item])
            else
                error("Unsupported meeting day type: $(typeof(item))")
            end
        end
        unique!(days)
        return days[filter(!isnothing, indexin(DAYSOFWEEKSYMBOLCODES, days))]
    else
        error("Cannot parse meeting frequency of type $(typeof(input)): $input")
    end
end


# const DATETIME_REGEX = r"\d{8}T\d{9}"
const DATETIME_REGEX = r"^(?P<year>\d{4}})(?P<month>\d{2}})(?P<day>\d{2}})T(?P<hour>\d{2}})(?P<minute>\d{2}})(?P<second>\d{2}})(?P<millisecond>\d{3}})$"

"""
    safe_datetime_stamp(dt::DateTime) = replace(string(dt), "-"=>"", ":"=>"", "."=>"")

Converts `Dates.DateTime` to a string safe for file paths.
"""
safe_datetime_stamp(dt::DateTime)   = replace(string(dt), "-"=>"", ":"=>"", "."=>"")
safe_datetime_stamp()               = safe_datetime_stamp(now())
safe_datetime_stamp(::Nothing)      = safe_datetime_stamp(now())

"Safely append datetime stamp to file name."
function safe_datetime_stamp(path::String)
    dir, base, name, ext = dirbasenameextname(path)
    datetimestamp = match(DATETIME_REGEX, string(split(name, "+")[end]))
    return name * "+" * (isnothing(datetimestamp) ? safe_datetime_stamp() : datetimestamp) * ext
end


"Magically converts `t` to `Dates.Time`. Defaults to ISO 8601."
function parse_time(t)
    if isa(t, Time)
        return t
    elseif isa(t, String)
        try
            return Time(t)
        catch
            try
                function parse_time_g(df)
                    return try
                        Time(t, df)
                    catch exc
                        if isa(exc, ArgumentError)
                            nothing
                        else
                            error("Could not parse time=$t")
                        end
                    end
                end
                time_variations = ["H:M:S.s", "H:M:S", "H:M", "H.M.S.s", "H.M.S", "H.M", "HHMMSSsss", "HHMMSS", "HHMM", "I:M p", "I.M p", "I:MMp", "I.MMp", "IIMM p", "IIMMp"]
                timeformats = DateFormat.(time_variations)
                i, parse, n = 0, nothing, length(timeformats)
                while isnothing(parse)
                    i += 1
                    if i == n + 1
                        return nothing
                    end
                    parse = parse_time_g(timeformats[i])
                end
                return parse
            catch
                error("Could not parse datetime=$d")
            end
        end
    else
        @info "Must be of type `DateTime` or `String` but is" typeof(t)
        error("Could not parse datetime=$t")
    end
end


"Magically converts `d` to `Dates.Date`. Defaults to ISO 8601. (Uses `DATE_FORMAT` preference.)"
function parse_date(d)
    if isa(d, Date)
        d = if Year(d) == Year(1)
            Date(Year(now()), month(d), day(d))
        else
            d
        end
        return d
    elseif isa(d, String)
        try
            return Date(d, ISODateFormat)
        catch
            try
                function parse_date_g(df)
                    return try
                        Date(d, df)
                    catch exc
                        nothing
                    end
                end
                date_variations = if DATE_FORMAT == "MMDDYYYY"
                    ["y-m-d", "m-d", "yyyymmdd", "m/d/y", "m/d", "U d, y", "U d", "u. d, y", "u. d", "u d, y", "u d"]
                elseif DATE_FORMAT == "DDMMYYYY"
                    ["y-m-d", "d-m", "yyyymmdd", "d/m/y", "d/m", "d U y", "d U", "d u. y", "d u.", "d u y", "d u"]
                else
                    error("Invalid `DATE_FORMAT` preference. Please set to one of: MMDDYYYY, DDMMYYYY")
                end
                dateformats = DateFormat.(date_variations)
                i, parse, n = 0, nothing, length(dateformats)
                while isnothing(parse)
                    i += 1
                    if i == n + 1
                        return nothing
                    end
                    parse = parse_date_g(dateformats[i])
                end
                d = parse
                d = if Year(d) == Year(1)
                    Date(Year(now()), month(d), day(d))
                else
                    d
                end
                return d
            catch
                error("Could not parse datetime=$d")
            end
        end
    else
        @info "Must be of type `Date` or `String` but is" typeof(d)
        error("Could not parse datetime=$d")
    end
end


"Magically converts `dt` to `Dates.DateTime`. Defaults to ISO 8601. (Uses `DATE_FORMAT` preference.)"
function parse_datetime(dt)
    if isa(dt, DateTime) || isa(dt, Millisecond)
        return dt
    elseif isa(dt, Date)
        d = if Year(dt) == Year(1)
            Date(Year(now()), month(dt), day(dt))
        else
            dt
        end
        return DateTime(d, MIDNIGHT)
    elseif isa(dt, String)
        try
            return DateTime(parse_date(dt), MIDNIGHT)
        catch
            try
                try
                    return DateTime(Date(dt, ISODateFormat), MIDNIGHT)
                catch
                    return DateTime(dt, ISODateTimeFormat)
                end
            catch
                try
                    function parse_datetime_g(df)
                        return try
                            DateTime(dt, df)
                        catch exc
                            nothing
                        end
                    end
                    date_variations = if DATE_FORMAT == "MMDDYYYY"
                        ["y-m-d", "m-d", "yyyymmdd", "m/d/y", "m/d", "U d, y", "U d", "u. d, y", "u. d", "u d, y", "u d"]
                    elseif DATE_FORMAT == "DDMMYYYY"
                        ["y-m-d", "d-m", "yyyymmdd", "d/m/y", "d/m", "d U y", "d U", "d u. y", "d u.", "d u y", "d u"]
                    else
                        error("Invalid `DATE_FORMAT` preference. Please set to one of: MMDDYYYY, DDMMYYYY")
                    end
                    time_variations = ["H:M:S.s", "H:M:S", "H:M", "H.M.S.s", "H.M.S", "H.M", "HHMMSSsss", "HHMMSS", "HHMM", "I:M p", "I.M p", "I:MMp", "I.MMp", "IIMM p", "IIMMp"]
                    datetimeformats = DateFormat.(vcat(
                        vcat(vcat(map(delim->map(ds->map(ts->join([ds, ts], delim), time_variations), date_variations[1:3]), ["T", " ", ""])...)...),
                        vcat(vcat(map(delim->map(ds->map(ts->join([ds, ts], delim), time_variations), date_variations[4:end]), [" "])...)...),
                    ))
                    i, parse, n = 0, nothing, length(datetimeformats)
                    while isnothing(parse)
                        i += 1
                        if i == n + 1
                            return nothing
                        end
                        parse = parse_datetime_g(datetimeformats[i])
                    end
                    dt′ = parse
                    # d = if Dates.value(Time(d)) == 0
                    #     DateTime(Date(d), MIDNIGHT)
                    # else
                    #     d
                    # end
                    return if Year(dt′) == Year(1)
                        DateTime(Date(Year(now()), month(dt′), day(dt′)), Time(dt′))
                    else
                        dt′
                    end
                catch
                    error("Could not parse datetime=$dt")
                end
            end
        end
    else
        @info "Must be of type `DateTime` or `String` but is" typeof(dt)
        error("Could not parse the datetime=$dt")
    end
end
