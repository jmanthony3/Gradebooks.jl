using Preferences

export ORGANIZATION, set_organization, get_organization
export ORG_IDPREFIX, set_orgidprefix, get_orgidprefix
export ORG_EMAILDOMAIN, set_orgemaildomain, get_orgemaildomain
export ORG_GRADESCALE, set_orggradescale, get_orggradescale
export COURSE_GRADESCALE, set_coursegradescale, get_coursegradescale

# TODO: can define Course or Class as preferences?
const ORGANIZATION = @load_preference("ORGANIZATION")
const ORG_IDPREFIX = @load_preference("ORG_IDPREFIX")
const ORG_EMAILDOMAIN = @load_preference("ORG_EMAILDOMAIN")
const ORG_GRADESCALE = @load_preference("ORG_GRADESCALE", 4)
const COURSE_GRADESCALE = @load_preference("COURSE_GRADESCALE", 1000)

function set_organization(org::String)
    @set_preferences!("ORGANIZATION" => org)
    @info("New `ORGANIZATION` set; restart your Julia session for this change to take effect!")
end

get_organization() = @load_preference("ORGANIZATION")

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

function set_orggradescale(scale::Integer)
    @set_preferences!("ORG_GRADESCALE" => scale)
    @info("New `ORG_GRADESCALE` set; restart your Julia session for this change to take effect!")
end

get_orggradescale() = @load_preference("ORG_GRADESCALE")

function set_coursegradescale(scale::Integer)
    @set_preferences!("COURSE_GRADESCALE" => scale)
    @info("New `COURSE_GRADESCALE` set; restart your Julia session for this change to take effect!")
end

get_coursegradescale() = @load_preference("COURSE_GRADESCALE")
