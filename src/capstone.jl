const EngineeringCapstone{T} = EngineeringCourse{T}

struct CapstoneProject{T} <: EngineeringCapstone{T}
    team_number::T
    project_title::T
    academic_year::T
end

struct CapstoneTeam{T} <: EngineeringCapstone{T}
    asdf
end

function CapstoneTeam(proj::CapstoneProject{T})
    CapstoneTeam{T}()
end

struct CapstoneClient{T,S} <: CapstoneProject{S}
    last::S
    first::S
    title::S=""
    suffix::S=""
    job_title::S=""
    email::S=""
    phone::S=""
    name::S=(title == "" ? "" : "$title ") * join([first, last]) * (suffix == "" ? "" : ", $suffix")
    codename::S=uppercase(join(map(s->first(s, 1), [first, last])))
end

struct CapstoneInstructor{T,S} <: CapstoneProject{S}
    last::S
    first::S
    title::S=""
    suffix::S=""
    job_title::S=""
    email::S=""
    phone::S=""
    name::S=(title == "" ? "" : "$title ") * join([first, last]) * (suffix == "" ? "" : ", $suffix")
    codename::S=uppercase(join(map(s->first(s, 1), [first, last])))
end
struct CapstoneStudent<:CapstoneProject
    last::String
    first::String
    title::String=""
    suffix::String=""
    discipline::String=""
    email::String=""
    phone::String=""
    is_lead::Bool=false
    name::String=(title == "" ? "" : "$title ") * join([first, last]) * (suffix == "" ? "" : ", $suffix")
    codename::String=uppercase(join(map(s->first(s, 1), [first, last])))
end

function get_emails(MX)
    capstone_project = JSON.parsefile("$MX/capstone_project_configuration.json")
    emailaddress_student = map(personnel->personnel["email"], capstone_project["student"])
    emailaddress_client = map(personnel->personnel["email"], capstone_project["client"])
    emailaddress_join(fromto, dict) = join(map(s->"$fromto:$s", dict))
    searchstring_fromstudent    = @sprintf("(%s) AND (%s)", emailaddress_join("from", emailaddress_student), emailaddress_join("to", emailaddress_client))
    searchstring_tostudent      = @sprintf("(%s) AND (%s)", emailaddress_join("to", emailaddress_student), emailaddress_join("from", emailaddress_client))
    fetch_emails(searchstring_fromstudent, csv)
    fetch_emails(searchstring_tostudent, csv)
end

function evaluate_health(MX::CapstoneProject)
    get_emails(MX)
    get_gradebook(MX)
end

function show_dashboard(class::Class)
    pmap(evaluate_health, class.teams)
    diagnosis = pmap(get_health, class.teams)
end