# # src/privacy.jl
# """
#     Gradebooks.Privacy

# Tools for FERPA-compliant redaction and pseudonymization of student data.

# - Operational data (Full clearance) keeps real PII.
# - Restricted / Public clearance replaces PII with stable, deterministic
#   pseudonyms so that unit tests and publications remain reproducible
#   without exposing identifying information.
# """
# module Privacy

export DataClearance, ispublic
export PseudonymMap, generate_pseudonym, create_pseudonym_map
export redact!
export sanitize_file, sanitize_csv, sanitize_directory



using CSV, DataFrames
using Dates, SHA, Random



# ─────────────────────────────────────────────────────────────────────────────
# Clearance levels
# ─────────────────────────────────────────────────────────────────────────────

@enum DataClearance begin
    Full        # real PII – teaching use only
    Restricted  # pseudonyms – local analysis / internal testing
    Public      # fully redacted – safe for GitHub & publication
end

ispublic(c::DataClearance) = c == Public

# ─────────────────────────────────────────────────────────────────────────────
# Pseudonym mapping (keep offline / encrypted)
# ─────────────────────────────────────────────────────────────────────────────

"""
    PseudonymMap

Stable, deterministic mapping from real student identifiers to synthetic ones.
Never commit the real→fake dictionary to a public repository.
"""
struct PseudonymMap
    real_to_fake::Dict{String, Dict{String,String}}
    salt::String
end

"""
    generate_pseudonym(real_id, salt) → String

Produce a deterministic synthetic identifier.
Same real_id + salt always yields the same result.
"""
function generate_pseudonym(identifier::AbstractString, type, salt::AbstractString)
    # Truncate hash for readability while remaining unique enough
    if type == :id
        h = bytes2hex(sha256(string(identifier, "|", salt)))[1:12]
        return "GB" * uppercase(h)
    elseif type ∈ (:lms_id, :name_given, :name_family, :name_suffix, :name_preferred, :name_initials, :name_aliases, :email, :name, :codename)
        h = uppercase(bytes2hex(sha256(string(identifier, "|", salt)))[1:12])
        if type == :lms_id
            return "LMS" * uppercase(h)
        end
        names = CSV.read(joinpath([@__DIR__, "census.csv"]), DataFrame; skipto=2, delim=" ")
        # map(rf->Int(floor(parse(Int64, rf[2][5:end], base=16)/(16^9))), collect(pm.real_to_fake))
        i = Int(floor(parse(Int64, h, base=16)/(16^9)))
        given = names[!, "First"][i]
        if type ∈ (:name_given, :name_preferred, :name_aliases)
            return given
        end
        j = nrow(names) - i
        family = names[!, "Last"][j]
        if type == :name_family
            return family
        end
        name = make_person_name(given, family)
        if type == :name
            return name
        end
        initials = string(make_person_codename(given, family))
        if type ∈ (:name_initials, :codename)
            return initials
        end
        email = lowercase(first(given) * family)
        # if !isnothing(INSTITUTION_EMAILDOMAIN)
        #     email = lowercase(join([email, INSTITUTION_EMAILDOMAIN], "@"))
        # end
        if type == :email
            return email
        end
    else
        error("Could construct pseudonym because type=$type was not of (:id, :name_given, :name_family, :email)")
    end
end

"""
    create_pseudonym_map(identifiers; salt=nothing) → PseudonymMap

Build a complete mapping for a vector of real identifiers (emails, IDs, names…).
If `salt` is omitted a random one is generated (store it securely!).
"""
function create_pseudonym_map(identifiers::AbstractVector{<:AbstractString}, roster::Roster;
                              salt::Union{Nothing,String}=nothing)
    salt = isnothing(salt) ? randstring(32) : salt
    real_to_fake = Dict{String, Dict{String, String}}()
    students = map(id->get_student(id, roster), identifiers)
    for student in students
        real_to_fake[string(student.person.id)] = Dict{String, String}()
        real_to_fake[string(student.person.id)][string(student.person.name_given)] = generate_pseudonym(string(student.person.id), :name_given, salt)
        real_to_fake[string(student.person.id)][string(student.person.name_family)] = generate_pseudonym(string(student.person.id), :name_family, salt)
        if !isempty(student.lms_id)
            real_to_fake[string(student.person.id)][string(student.lms_id)] = generate_pseudonym(string(student.person.id), :lms_id, salt)
        end
        if !isempty(student.person.name_suffix)
            real_to_fake[string(student.person.id)][string(student.person.name_suffix)] = generate_pseudonym(string(student.person.id), :name_suffix, salt)
        end
        if !isempty(student.person.name_preferred)
            real_to_fake[string(student.person.id)][string(student.person.name_preferred)] = generate_pseudonym(string(student.person.id), :name_preferred, salt)
        end
        if !isempty(string(student.person.name_initials))
            real_to_fake[string(student.person.id)][string(student.person.name_initials)] = generate_pseudonym(string(student.person.id), :name_initials, salt)
        end
        if !isempty(student.person.name_aliases)
            for alias in student.person.name_aliases
                real_to_fake[string(student.person.id)][string(alias)] = generate_pseudonym(string(student.person.id), :name_aliases, salt)
            end
        end
        if !isempty(student.person.email)
            real_to_fake[string(student.person.id)][string(split(student.person.email, "@")[1])] = generate_pseudonym(string(student.person.id), :email, salt)
        end
        if !isempty(student.person.id)
            real_to_fake[string(student.person.id)][string(student.person.id)] = generate_pseudonym(string(student.person.id), :id, salt)
        end
        if !isempty(student.person.name)
            real_to_fake[string(student.person.id)][string(student.person.name)] = generate_pseudonym(string(student.person.id), :name, salt)
        end
        if !isempty(string(student.person.codename))
            real_to_fake[string(student.person.id)][string(student.person.codename)] = generate_pseudonym(string(student.person.id), :codename, salt)
        end
    end
    return PseudonymMap(real_to_fake, salt)
end
create_pseudonym_map(roster::Roster;    salt::Union{Nothing,String}=nothing) = create_pseudonym_map(map(s->s.person.id, roster.students), roster; salt=salt)
create_pseudonym_map(class::Class;      salt::Union{Nothing,String}=nothing) = create_pseudonym_map(class.roster; salt=salt)
create_pseudonym_map(gb::Gradebook;     salt::Union{Nothing,String}=nothing) = create_pseudonym_map(gb.class; salt=salt)

# Convenience: look up or generate on the fly
function get_pseudonym(map::PseudonymMap, real_identifier::AbstractString, type)
    get!(map.real_to_fake, string(real_identifier)) do
        generate_pseudonym(real_identifier, type, map.salt)
    end
end

# ─────────────────────────────────────────────────────────────────────────────
# Redaction of in-memory Gradebook objects
# ─────────────────────────────────────────────────────────────────────────────

"""
    redact!(gb, map; level=Public)

Replace all PII in the Gradebook with stable pseudonyms.
Mutates the Gradebook in place and sets its clearance level.
"""
function redact!(gb, map::PseudonymMap; level::DataClearance=Public)
    # 1. Roster
    for s in gb.roster
        # Choose a stable key – prefer real student ID, fall back to email/name
        key = something(get(s, :id, nothing),
                        get(s, :email, nothing),
                        get(s, :name, "UNKNOWN"))
        key = string(key)

        fake = get_pseudonym(map, key)

        # Overwrite identifying fields
        if hasproperty(s, :name)
            s.name = fake
        end
        if hasproperty(s, :email)
            s.email = "$(fake)@example.edu"
        end
        if hasproperty(s, :id)
            s.id = fake
        end
        if hasproperty(s, :nickname)
            s.nickname = nothing
        end
        # Add any other PII fields you store on Student here
    end

    # 2. Any other places that store free-text comments containing names
    #    can be scrubbed here if needed (e.g. evaluation comments).

    # 3. Mark the Gradebook as redacted
    if hasproperty(gb, :clearance)
        gb.clearance = level
    end

    return gb
end

# ---------------------------------------------------------------
# Content-based redaction (works on any text file)
# ---------------------------------------------------------------
# (?(?=@)((\w+)(@.*)?)|((([a-zA-Z]*)(\d+))))
# \b(\w+)((@[\w.\-+]+)?)\b

# """
#     redact_text(text, map) → String

# Replace every occurrence of the real identifiers stored in `map`
# with their corresponding pseudonyms.
# """
# function redact_text(text::AbstractString, map::PseudonymMap; forbidden::AbstractVector{<:AbstractString}=String[])
#     result = text
#     for (_, fake_dict) in map.real_to_fake
#         sorted_keys = sort(collect(keys(fake_dict)); by=length, rev=true)
#         for real in sorted_keys
#             forbidden_idx = Int[]
#             if !isempty(forbidden)
#                 for forb in forbidden
#                     append!(forbidden_idx, findall(Regex("$(escape_string(forb))", "i"), result)...)
#                 end
#             end
#             fake = fake_dict[real]
#             pattern = Regex("\\b$(escape_string(real))(@[\\w\\.]*)?\\b", "i")
#             # recompute forbidden ranges on the current result so indices stay valid
#             offsets = [m.offset for m in eachmatch(pattern, result)]
#             result = replace(result, pattern=>(m->(!isempty(intersect(m.offset .+ (0:length(m.string)-1), forbidden_idx)) ? m.string : fake)))
#         end
#     end
#     return result
# end

"""
    redact_text(text, map;
                pattern = r"\\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}\\b" ,
                protected = String[])

Replace every match of `pattern` with the corresponding pseudonym
from `map`, **except** when the match is a substring of (or overlaps)
any string in `protected`.

`protected` is typically the list of keys you do **not** want scrambled
(e.g. course codes, assignment codenames, known safe tokens, etc.).
"""
function redact_text(text::AbstractString,
                     map::PseudonymMap;
                    #  pattern::Regex = r"\b[\w.+-]+@[\w.-]+\.\w+\b",  # example: emails
                     protected::AbstractVector{<:AbstractString} = String[])

    # 1. Collect protected ranges (start, stop) – longest first helps a bit
    protected_ranges = Tuple{Int,Int}[]
    for p in sort(protected; by=length, rev=true)
        for m in eachmatch(Regex(escape_string(p)), text)
            push!(protected_ranges, (m.offset, m.offset + length(m.match) - 1))
        end
    end

    # Helper: does [a,b] overlap any protected range?
    overlaps(a, b, ranges) = any(s ≤ b && e ≥ a for (s, e) in ranges)

    # 2. Find all candidate matches and keep only the safe ones
    #    We store (start, stop, replacement) and process from the end
    #    so that earlier indices stay valid.
    replacements = Tuple{Int,Int,String}[]

    for (id, fake_dict) in map.real_to_fake
        sorted_keys = sort(collect(keys(fake_dict)); by=length, rev=true)
        for real in sorted_keys
            # @show real
            search = real
            if real == id && !isnothing(INSTITUTION_IDPREFIX) && startswith(real, INSTITUTION_IDPREFIX)
                search = real[length(INSTITUTION_IDPREFIX)+1:end]
            end
            pattern = !isnothing(INSTITUTION_IDPREFIX) ? Regex("\\b(($INSTITUTION_IDPREFIX)?$(escape_string(search)))(@[\\w.\\-+]+)?\\b", "i") : Regex("\\b($(escape_string(search)))(@[\\w.\\-+]+)?\\b", "i")
            for m in eachmatch(pattern, text)
                # @show m
                start = m.offset
                stop  = start + length(m.match) - 1

                # Skip if this match sits inside a protected string
                overlaps(start, stop, protected_ranges) && continue

                overlaps(start, stop, [(s, e) for (s, e, _) in replacements]) && continue

                # Look up the pseudonym (or generate one on the fly)
                # search = m.captures[1]
                if haskey(fake_dict, real)
                    fake = fake_dict[real]
                    push!(replacements, (start, stop, fake))
                end
            end
        end
    end

    # 3. Apply replacements from the end of the string backwards
    result = text
    for (start, stop, fake) in sort(replacements; by = x -> x[1], rev = true)
        result = result[1:start-1] * fake * result[stop+1:end]
    end
    # parts = String[]
    # last = 1
    # for (a, b, fake) in replacements
    #     push!(parts, text[last:a-1])   # unchanged chunk
    #     push!(parts, fake)             # replacement
    #     last = b + 1
    # end
    # push!(parts, text[last:end])       # final unchanged chunk
    # result = join(parts)

    return result
end

"""
    sanitize_file(path, map; out_dir="redacted", overwrite=false)

Read the entire file as a string, replace every occurrence of known
real identifiers with their corresponding pseudonyms, and write the
result to `out_dir`.

Returns the path of the written file.
"""
function sanitize_file(path::AbstractString, map::PseudonymMap;
                       out_dir::AbstractString="redacted",
                       overwrite::Bool=false)

    mkpath(out_dir)
    content = read(path, String)

    protected = String[]
    if splitext(path)[2] == ".csv"
        append!(protected, filter(!isempty, names(CSV.read(path, DataFrame; limit=1))))
    end

    sanitized = redact_text(content, map; protected=protected)

    dest = joinpath(out_dir, basename(path))
    if isfile(dest) && !overwrite
        error("Destination already exists: $dest  (pass overwrite=true to replace)")
    end
    write(dest, sanitized)
    return dest
end

"""
    sanitize_directory(dir, map; out_dir="redacted", recursive=true)

Walk a directory and sanitize every regular file.
"""
function sanitize_directory(dir::AbstractString, map::PseudonymMap;
                            out_dir::AbstractString="redacted",
                            overwrite::Bool=false,
                            recursive::Bool=true)

    mkpath(out_dir)
    results = String[]

    for (root, _, files) in walkdir(dir)
        for f in files
            src = joinpath(root, f)
            rel = relpath(src, dir)
            dest_dir = joinpath(out_dir, dirname(rel))
            mkpath(dest_dir)

            res = sanitize_file(src, map; out_dir=dest_dir, overwrite=overwrite)
            push!(results, res)
            # try
            # catch e
            #     @warn "Could not sanitize $src" exception=e
            # end
        end
        recursive || break
    end
    return results
end
