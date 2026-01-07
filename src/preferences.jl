using Preferences

const ORG_IDPREFIX = @load_preference("ORG_IDPREFIX")
const ORG_EMAILDOMAIN = @load_preference("ORG_EMAILDOMAIN")

function set_orgidprefix(prefix::String)
    @set_preferences!("ORG_IDPREFIX" => prefix)
    @info("New `ORG_IDPREFIX` set; restart your Julia session for this change to take effect!")
end

get_orgidprefix() = @load_preference("ORG_IDPREFIX")

function set_orgemaildomain(domain::String)
    @set_preferences!("ORG_EMAILDOMAIN" => domain)
    @info("New `ORG_EMAILDOMAIN` set; restart your Julia session for this change to take effect!")
end

get_orgemaildomain() = @load_preference("ORG_EMAILDOMAIN")