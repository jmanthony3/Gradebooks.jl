public DAYSYMBOLMAP
public MWF, TR
export MIDNIGHT
public frequency2symbols
public safe_datetime_stamp, parse_time, parse_date, parse_datetime

using Dates

const DAYSYMBOLMAP = Dict(
    :Sunday=>:U,        "Sunday"=>:U,       "U"=>:U,    'U'=>:U,
    :Monday=>:M,        "Monday"=>:M,       "M"=>:M,    'M'=>:M,
    :Tuesday=>:T,       "Tuesday"=>:T,      "T"=>:T,    'T'=>:T,
    :Wednesday=>:W,     "Wednesday"=>:W,    "W"=>:W,    'W'=>:W,
    :Thursday=>:R,      "Thursday"=>:R,     "R"=>:R,    'R'=>:R,
    :Friday=>:F,        "Friday"=>:F,       "F"=>:F,    'F'=>:F,
    :Saturday=>:S,      "Saturday"=>:S,     "S"=>:S,    'S'=>:S,
)
const MWF = [:M, :W, :F]
const TR = [:T, :R]
const MIDNIGHT = Time(23, 59, 59, 999)

function frequency2symbols(input)::Vector{Symbol}
    input === nothing && return Symbol[]

    # Case 1: Single Symbol shorthand like :MWR, :MW, :TR
    if input isa Symbol
        if input == MWF || input == TR
            return input
        end
        s = uppercase(string(input))
        days = Symbol[]
        for c in s
            day = get(DAYSYMBOLMAP, Symbol(c), nothing)
            day === nothing && error("Unknown day code: $c in :$s")
            push!(days, day)
        end
        return unique(days)  # safety
    end

    # Case 2: Vector of anything
    if input isa AbstractVector
        days = Symbol[]
        for item in input
            if item isa Symbol || item isa AbstractString || item isa Char
                key = item isa Char ? Symbol(uppercase(string(item))) : Symbol(uppercase(string(item)))
                day = get(DAYSYMBOLMAP, key, nothing)
                day === nothing && error("Unknown day: $item")
                push!(days, day)
            else
                error("Unsupported meeting day type: $(typeof(item))")
            end
        end
        return unique(days)
    end

    error("Cannot parse meeting frequency of type $(typeof(input)): $input")
end

safe_datetime_stamp(dt::DateTime)   = replace(string(dt), "-"=>"", ":"=>"", "."=>"")
safe_datetime_stamp()               = safe_datetime_stamp(now())
safe_datetime_stamp(::Nothing)      = safe_datetime_stamp(now())
function safe_datetime_stamp(path::String)
    dir, base, name, ext = dirbasenameextname(path)
    datetimestamp = match(DATETIME_REGEX, string(split(name, "+")[end]))
    return name * "+" * (isnothing(datetimestamp) ? safe_datetime_stamp() : datetimestamp) * ext
end

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
                            @error "Could not parse..."
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
                @error "I could not parse the datetime..." d
            end
        end
    else
        @info "Must be `DateTime` or `String` but is" typeof(t)
        @error "I could not parse the datetime..." t
    end
end

function parse_date(d)
    if isa(d, Date)
        d = if year(d) == 1
            Date(year(now()), month(d), day(d))
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
                date_variations = if DATE_FORMAT == :MMDDYYYY
                    ["y-m-d", "m-d", "yyyymmdd", "m/d/y", "m/d", "U d, y", "U d", "u. d, y", "u. d", "u d, y", "u d"]
                elseif DATE_FORMAT == :DDMMYYYY
                    ["y-m-d", "d-m", "yyyymmdd", "d/m/y", "d/m", "d U y", "d U", "d u. y", "d u.", "d u y", "d u"]
                else
                    @error "Invalid `DATE_FORMAT` preference. Please set to one of: $(join(VALID_DATE_FORMATS, ", "))"
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
                d = if year(d) == 1
                    Date(year(now()), month(d), day(d))
                else
                    d
                end
                return d
            catch
                @error "I could not parse the datetime..." d
            end
        end
    else
        @info "Must be `Date` or `String` but is" typeof(d)
        @error "I could not parse the datetime..." d
    end
end

function parse_datetime(d)
    if isa(d, DateTime) || isa(d, Millisecond)
        return d
    elseif isa(d, Date)
        d = if year(d) == 1
            Date(year(now()), month(d), day(d))
        else
            d
        end
        return DateTime(d, MIDNIGHT)
    elseif isa(d, String)
        try
            return DateTime(parse_date(d), MIDNIGHT)
        catch
            try
                try
                    return DateTime(Date(d, ISODateFormat), MIDNIGHT)
                catch
                    return DateTime(d, ISODateTimeFormat)
                end
            catch
                try
                    function parse_datetime_g(df)
                        return try
                            DateTime(d, df)
                        catch exc
                            nothing
                        end
                    end
                    date_variations = if DATE_FORMAT == :MMDDYYYY
                        ["y-m-d", "m-d", "yyyymmdd", "m/d/y", "m/d", "U d, y", "U d", "u. d, y", "u. d", "u d, y", "u d"]
                    elseif DATE_FORMAT == :DDMMYYYY
                        ["y-m-d", "d-m", "yyyymmdd", "d/m/y", "d/m", "d U y", "d U", "d u. y", "d u.", "d u y", "d u"]
                    else
                        @error "Invalid `DATE_FORMAT` preference. Please set to one of: $(join(VALID_DATE_FORMATS, ", "))"
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
                    d = parse
                    # d = if Dates.value(Time(d)) == 0
                    #     DateTime(Date(d), MIDNIGHT)
                    # else
                    #     d
                    # end
                    return if year(d) == 1
                        DateTime(Date(year(now()), month(d), day(d)), Time(d))
                    else
                        d
                    end
                catch
                    @error "I could not parse the datetime..." d
                end
            end
        end
    else
        @info "Must be `DateTime` or `String` but is" typeof(d)
        @error "I could not parse the datetime..." d
    end
end
