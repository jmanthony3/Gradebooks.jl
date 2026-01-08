export MIDNIGHT, safe_datetime_stamp
export dayname_codes, dayabbr_codes, dayname2codename
export parse_time, parse_datetime

using Dates

const MIDNIGHT = Time(23, 59, 59, 999)

safe_datetime_stamp() = replace(string(now()), "-"=>"", ":"=>".") # , "."=>"")
safe_datetime_stamp(dt::DateTime) = replace(string(dt), "-"=>"", ":"=>".") # , "."=>"")

dayname_codes = (Sunday=:U, Monday=:M, Tuesday=:T, Wednesday=:W, Thursday=:R, Friday=:F, Saturday=:S)
dayabbr_codes = (Sun=dayname_codes[:Sunday], Mon=dayname_codes[:Monday], Tues=dayname_codes[:Tuesday], Wed=dayname_codes[:Wednesday], Thu=dayname_codes[:Thursday], Fri=dayname_codes[:Friday], Sat=dayname_codes[:Saturday])

function dayname2codename(s::String)
    articles = ["a", "an", "the"]
    conjuctions = ["for", "and", "nor", "but", "or", "yet", "so"]
    prepositions = ["of", "in", "for", "with", "on", "at", "from", "into", "during", "through", "without", "under", "over", "above", "below", "to"]
    forbidden = vcat(articles, conjuctions, prepositions)
    tokens = uppercasefirst.(lowercase.(filter(s->lowercase(s) .∉ forbidden, split(filter(!ispunct, s), " "))))
    dayname_codes_str = string.(keys(dayname_codes))
    return mapreduce(t->dayname_codes[findfirst(occursin(t, dayname_codes_str))], *, tokens)
end
function dayname2codename(s::Vector{String})
    return mapreduce(dayname2codename, *, s)
end
dayname2codename(s::Symbol) = dayname2codename("$s")
dayname2codename(s::Vector{Symbol}) = dayname2codename(map(x->"$x", s))

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
                time_variations = ["H:M:S.s", "H.M.S.s", "H:M", "H.M", "HHMM", "I:M p", "I.M p", "I:MMp", "I.MMp", "IIMM p", "IIMMp"]
                timeformats = DateFormat.(time_variations)
                i, parse, n = 0, nothing, length(timeformats)
                while isnothing(parse)
                    i += 1
                    if i == n + 1
                        @error "Could not parse..."
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

function parse_datetime(d)
    if isa(d, DateTime)
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
            return DateTime(d, ISODateTimeFormat)
        catch
            try
                return DateTime(Date(DateTime(d, ISODateFormat)), MIDNIGHT)
            catch
                try
                    function parse_datetime_g(df)
                        return try
                            DateTime(d, df)
                        catch exc
                            if isa(exc, ArgumentError)
                                nothing
                            else
                                @error "Could not parse..."
                            end
                        end
                    end
                    date_variations = ["y-m-d", "m-d", "yyyymmdd", "m/d/y", "m/d", "U d, y", "U d", "u. d, y", "u. d", "u d, y", "u d"]
                    time_variations = ["H:M:S.s", "H.M.S.s", "H:M", "H.M", "HHMM", "I:M p", "I.M p", "I:MMp", "I.MMp", "IIMM p", "IIMMp"]
                    datetimeformats = DateFormat.(vcat(
                        vcat(vcat(map(delim->map(ds->map(ts->join([ds, ts], delim), time_variations), date_variations[1:3]), ["T", " ", ""])...)...),
                        vcat(vcat(map(delim->map(ds->map(ts->join([ds, ts], delim), time_variations), date_variations[4:end]), [" "])...)...),
                    ))
                    i, parse, n = 0, nothing, length(datetimeformats)
                    while isnothing(parse)
                        i += 1
                        if i == n + 1
                            @error "Could not parse..."
                        end
                        parse = parse_datetime_g(datetimeformats[i])
                    end
                    d = parse
                    d = if Dates.value(Time(d)) == 0
                        DateTime(d, MIDNIGHT)
                    else
                        d
                    end
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
