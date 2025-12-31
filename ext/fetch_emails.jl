PYTHON_VERSION = "python314"

fetch_emails(from, to) = `$PYTHON_VERSION fetch_emails $from $to`

function evaluate_health(class::Class)
    get_gradebook(class)
end