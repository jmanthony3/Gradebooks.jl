export safe_datetime_stamp, parse_datetime
export score_letter

safe_datetime_stamp() = replace(string(now()), "-"=>"", ":"=>".") # , "."=>"")
safe_datetime_stamp(dt::DateTime) = replace(string(dt), "-"=>"", ":"=>".") # , "."=>"")

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
                    function parse_datetime(df)
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
                        parse = parse_datetime(datetimeformats[i])
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
