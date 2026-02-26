export view_gradebook, view_attendance



# using Plots; gr()
using RecipesBase
using PrettyTables, Colors, ColorSchemes

# default(
#     fontfamily="Computer Modern",
#     linewidth=1,
#     framestyle=:box,
#     label=nothing,
#     grid=false)
# scalefontsizes(1.3)



@userplot ViewGradebook
# @userplot ViewAttendance

@recipe f(::Type{Gradebook}, gb::Gradebook) = gb.data

function view_gradebook(gb::Gradebook, att::Gradebook, assignments::Vector{Assignment})
    final_grades = zeros((nrow(gb.total), 1))
    for (i, row) in enumerate(eachrow(gb.total))
        final_grades[i] = (collect(select(DataFrame(row), Not(["ID", "Preferred", "Last", "Team", "Email"]))[1, :]) |> sum) - att.penalty[i, end]
    end

    data = gb.total[!, Cols(["ID", "Preferred", "Last", "Team", "Email"], map(x->x.codename, assignments))]
    insertcols!(data, "Total"=>Points.(vec(final_grades)))
    insertcols!(data, "Percent"=>Percentage.(vec(final_grades ./ sum(map(x->x.value, collect(assignments))))))
    insertcols!(data, "Letter"=>score2letter.(Percentage.(vec(final_grades ./ sum(map(x->x.value, collect(assignments)))))))
    insertcols!(data, "Missing"=>Points.(abs.(vec(final_grades) .- mapreduce(x->x.value, +, assignments))))
    row_labels = [join(collect(row[1:5]), " ") for row in eachrow(data)]
    column_labels = [
        names(data),
        vcat(fill("", 5), map(x->repr(typeof(x).parameters[1])[9:end], assignments)..., ["Course", "Course", "Course", "Course"]),
        vcat(fill("", 5), map(x->typeof(x).parameters[2], assignments)..., ["Individual", "Individual", "Individual", "Individual"]),
        vcat(fill("", 5), map(x->typeof(x).types[2], assignments)..., ["Points", "Percentage", "Letter", "Points"]),
    ]
    # Function to determine color based on value
    function gradient_highlighter(_, data, i, j)
        if 5 < j <= ncol(data)
            val = if j < ncol(data) - 1
                (data[i, j] == 0.0 ? 0.0 : data[i, j] / maximum(data[:, j]))
            elseif j == ncol(data)
                1.0 - (data[i, j] == 0.0 ? 0.0 : data[i, j] / maximum(data[:, j]))
            else
                (data[i, j] == 0.0 ? 0.0 : data[i, j-1] / maximum(data[:, j-1]))
            end
            # Map value (assuming 0-1 range) to a color from a scheme
            color = get(colorschemes[:RdYlGn], val) # , :extrema)
            hex_color = "#" * hex(color)
            return ["background-color"=>hex_color]
        else
            return false
        end
    end
    hl_data = HtmlHighlighter(
            (data, i, j) -> (j >= 6), # && (data[i, j] > 0.0),
            gradient_highlighter
            # ["color"=>"blue", "font-weight"=>"bold"]
        )
    hl_total = HtmlHighlighter(
            (data, i, j) -> (j == ncol(data)-3),
            ["font-weight"=>"bold"]
        )
    hl_percent = HtmlHighlighter(
            (data, i, j) -> (j == ncol(data)-2),
            ["font-weight"=>"italic"]
        )
    hl_letter = HtmlHighlighter(
            (data, i, j) -> (j == ncol(data)-1), # && (data[i, j] > 0.0),
            gradient_highlighter
            # ["color"=>"blue", "font-weight"=>"bold"]
        )
    hl_missing = HtmlHighlighter(
            (data, i, j) -> (j == ncol(data)), # && (data[i, j] > 0.0),
            gradient_highlighter
            # ["color"=>"blue", "font-weight"=>"bold"]
        )
    p = PrettyTable(
        data;
        title           = "$(gb.who.codename_long): $(gb.who.course.name)",
        subtitle        = "Class Gradebook",
        row_labels      = row_labels,
        column_labels   = column_labels,
        summary_row_labels=["Worth", "Due", "Average (Points)", "Average (Percentage)"], # , "S.Dev", "Running Average (Percentage)"],
        summary_rows    = [
            (matrix, j)->j == ncol(data)-3 ? mapreduce(x->x.value, +, assignments) : ((5 < j <= length(assignments)+5) ? assignments[j - 5].value : ""),
            (matrix, j)->(5 < j <= length(assignments)+5) ? assignments[j - 5].due : "",
            (matrix, j)->j == ncol(data)-3 ? mapreduce(x->x.value, +, assignments) : (
                j == ncol(data)-2 ? (Points.(sum(data[:, j-1])/length(data[:, j-1])) / mapreduce(x->x.value, +, assignments)) : (
                    j == ncol(data)-1 ? score2letter(Points.(sum(data[:, j-2])/length(data[:, j-2])) / mapreduce(x->x.value, +, assignments)) : (
                        j == ncol(data) ? Points.(sum(data[:, j])/length(data[:, j])) : (
                            (5 < j <= length(assignments)+5) ? Points.(sum(data[:, j])/length(data[:, j])) : "")))),
            (matrix, j)->(5 < j <= length(assignments)+5) ? Percentage.(Points.(sum(data[:, j])/length(data[:, j]))/assignments[j - 5].value) : "",
            # (data, i, j)->,
            # (data, i, j)->
        ],
        style           = HtmlTableStyle(; first_line_column_label = ["font-weight"=>"bold"], column_label = ["color"=>"gray", "font-style"=>"italic"]),
        highlighters    = [hl_data, hl_total, hl_percent, hl_letter, hl_missing],
        table_format    = HtmlTableFormat("""
    .table-wrapper {
    overflow: auto; /* Enables scrolling within the container */
    max-height: 400px; /* Optional: Sets a maximum height for vertical scrolling */
    max-width: 600px; /* Optional: Sets a maximum width for horizontal scrolling */
    }

    /* Make the header row sticky at the top */
    thead th {
    position: sticky;
    top: 0;
    background-color: #f1f1f1; /* Add a background color */
    z-index: 2; /* Ensures headers are above body cells when scrolling vertically */
    }

    /* Make the first column sticky on the left */
    tbody td:first-child,
    tbody th:first-child { /* Use th if your first column cells are headers */
    position: sticky;
    left: 0;
    background-color: #f9f9f9; /* Add a background color */
    z-index: 1; /* Ensures the first column is above other body cells when scrolling horizontally */
    }

    /* Ensure the top-left corner cell (header of the first column) is above everything */
    thead th:first-child {
    z-index: 3; /* Must be the highest z-index */
    }

    /* Optional: Add borders and spacing for better visual separation */
    table {
    border-collapse: separate;
    border-spacing: 0;
    }
    td, th {
    padding: 10px;
    border: 1px solid #ddd;
    }
    """, ""),
        backend         = :html,
        stand_alone     = true
    )
    out = joinpath([pwd(), "gradebook", "build", "gradebook.html"])
    mkpath(dirname(out))
    open(out, "w") do io
        write(io, repr(p))
    end
    run(`cmd /c start $out`)
end

function view_gradebook(gb::Gradebook, att::Gradebook, identifier::String, assignments::Vector{Assignment})
    final_grades = zeros((nrow(gb.total), 1))
    for (i, row) in enumerate(eachrow(gb.total))
        final_grades[i] = (collect(select(DataFrame(row), Not(["ID", "Preferred", "Last", "Team", "Email"]))[1, :]) |> sum) - att.penalty[i, end]
    end

    data = gb.total[!, Cols(["ID", "Preferred", "Last", "Team", "Email"], map(x->x.codename, assignments))]
    insertcols!(data, "Total"=>Points.(vec(final_grades)))
    insertcols!(data, "Percent"=>Percentage.(vec(final_grades ./ sum(map(x->x.value, collect(assignments))))))
    insertcols!(data, "Letter"=>score2letter.(Percentage.(vec(final_grades ./ sum(map(x->x.value, collect(assignments)))))))
    insertcols!(data, "Missing"=>Points.(abs.(vec(final_grades) .- mapreduce(x->x.value, +, assignments))))
    row_labels = [join(collect(row[1:5]), " ") for row in eachrow(data)]
    column_labels = [
        names(data),
        vcat(fill("", 5), map(x->repr(typeof(x).parameters[1])[9:end], assignments)..., ["Course", "Course", "Course", "Course"]),
        vcat(fill("", 5), map(x->typeof(x).parameters[2], assignments)..., ["Individual", "Individual", "Individual", "Individual"]),
        vcat(fill("", 5), map(x->typeof(x).types[2], assignments)..., ["Points", "Percentage", "Letter", "Points"]),
    ]
    # Function to determine color based on value
    function gradient_highlighter(_, data, i, j)
        if 5 < j <= ncol(data)
            val = if j < ncol(data) - 1
                (data[i, j] == 0.0 ? 0.0 : data[i, j] / maximum(data[:, j]))
            elseif j == ncol(data)
                1.0 - (data[i, j] == 0.0 ? 0.0 : data[i, j] / maximum(data[:, j]))
            else
                (data[i, j] == 0.0 ? 0.0 : data[i, j-1] / maximum(data[:, j-1]))
            end
            # Map value (assuming 0-1 range) to a color from a scheme
            color = get(colorschemes[:RdYlGn], val) # , :extrema)
            hex_color = "#" * hex(color)
            return ["background-color"=>hex_color]
        else
            return false
        end
    end
    hl_data = HtmlHighlighter(
            (data, i, j) -> (j >= 6), # && (data[i, j] > 0.0),
            gradient_highlighter
            # ["color"=>"blue", "font-weight"=>"bold"]
        )
    hl_total = HtmlHighlighter(
            (data, i, j) -> (j == ncol(data)-3),
            ["font-weight"=>"bold"]
        )
    hl_percent = HtmlHighlighter(
            (data, i, j) -> (j == ncol(data)-2),
            ["font-weight"=>"italic"]
        )
    hl_letter = HtmlHighlighter(
            (data, i, j) -> (j == ncol(data)-1), # && (data[i, j] > 0.0),
            gradient_highlighter
            # ["color"=>"blue", "font-weight"=>"bold"]
        )
    hl_missing = HtmlHighlighter(
            (data, i, j) -> (j == ncol(data)), # && (data[i, j] > 0.0),
            gradient_highlighter
            # ["color"=>"blue", "font-weight"=>"bold"]
        )
    p = PrettyTable(
        data[occursin.(get_student(gb.who.roster, identifier).email, data[!, "Email"]), :];
        title           = "$(gb.who.codename_long): $(gb.who.course.name)",
        subtitle        = "Class Gradebook",
        row_labels      = row_labels,
        column_labels   = column_labels,
        summary_row_labels=["Worth", "Due", "Average (Points)", "Average (Percentage)"], # , "S.Dev", "Running Average (Percentage)"],
        summary_rows    = [
            (matrix, j)->j == ncol(data)-3 ? mapreduce(x->x.value, +, assignments) : ((5 < j <= length(assignments)+5) ? assignments[j - 5].value : ""),
            (matrix, j)->(5 < j <= length(assignments)+5) ? assignments[j - 5].due : "",
            (matrix, j)->j == ncol(data)-3 ? mapreduce(x->x.value, +, assignments) : (
                j == ncol(data)-2 ? (Points.(sum(data[:, j-1])/length(data[:, j-1])) / mapreduce(x->x.value, +, assignments)) : (
                    j == ncol(data)-1 ? score2letter(Points.(sum(data[:, j-2])/length(data[:, j-2])) / mapreduce(x->x.value, +, assignments)) : (
                        j == ncol(data) ? Points.(sum(data[:, j])/length(data[:, j])) : (
                            (5 < j <= length(assignments)+5) ? Points.(sum(data[:, j])/length(data[:, j])) : "")))),
            (matrix, j)->(5 < j <= length(assignments)+5) ? Percentage.(Points.(sum(data[:, j])/length(data[:, j]))/assignments[j - 5].value) : "",
            # (data, i, j)->,
            # (data, i, j)->
        ],
        style           = HtmlTableStyle(; first_line_column_label = ["font-weight"=>"bold"], column_label = ["color"=>"gray", "font-style"=>"italic"]),
        highlighters    = [hl_data, hl_total, hl_percent, hl_letter, hl_missing],
        table_format    = HtmlTableFormat("""
    .table-wrapper {
    overflow: auto; /* Enables scrolling within the container */
    max-height: 400px; /* Optional: Sets a maximum height for vertical scrolling */
    max-width: 600px; /* Optional: Sets a maximum width for horizontal scrolling */
    }

    /* Make the header row sticky at the top */
    thead th {
    position: sticky;
    top: 0;
    background-color: #f1f1f1; /* Add a background color */
    z-index: 2; /* Ensures headers are above body cells when scrolling vertically */
    }

    /* Make the first column sticky on the left */
    tbody td:first-child,
    tbody th:first-child { /* Use th if your first column cells are headers */
    position: sticky;
    left: 0;
    background-color: #f9f9f9; /* Add a background color */
    z-index: 1; /* Ensures the first column is above other body cells when scrolling horizontally */
    }

    /* Ensure the top-left corner cell (header of the first column) is above everything */
    thead th:first-child {
    z-index: 3; /* Must be the highest z-index */
    }

    /* Optional: Add borders and spacing for better visual separation */
    table {
    border-collapse: separate;
    border-spacing: 0;
    }
    td, th {
    padding: 10px;
    border: 1px solid #ddd;
    }
    """, ""),
        backend         = :html,
        stand_alone     = true
    )
    out = joinpath([pwd(), "gradebook", "build", "gradebook.html"])
    mkpath(dirname(out))
    open(out, "w") do io
        write(io, repr(p))
    end
    run(`cmd /c start $out`)
end

function view_attendance(att::Gradebook, lectures::Vector{Assignment})
    number_of_elective_absences = zeros((nrow(att.raw_score), 1))
    for (i, row) in enumerate(eachrow(att.raw_score))
        number_of_elective_absences[i] = count(==(0), collect(select(DataFrame(row), Not(["ID", "Preferred", "Last", "Email"]))[1, :]))
    end
    data = att.raw_score
    insertcols!(data, "Total"=>vec(number_of_elective_absences))
    # insertcols!(data, "Percent"=>Percentage.(vec(final_grades ./ sum(map(x->x.value, collect(assignments)[1:assignment_range_b])))))
    # insertcols!(data, "Letter"=>score2letter.(Percentage.(vec(final_grades ./ sum(map(x->x.value, collect(assignments)[1:assignment_range_b]))))))
    row_labels = [join(collect(row[1:4]), " ") for row in eachrow(data)]
    column_labels = [
        names(data),
        vcat(fill("", 4), map(x->repr(typeof(x).parameters[1])[9:end], lectures[1:ncol(data)-5])..., ["Course"]),
        vcat(fill("", 4), map(x->typeof(x).parameters[2], lectures[1:ncol(data)-5])..., ["Individual"]),
        vcat(fill("", 4), map(x->typeof(x).types[2], lectures[1:ncol(data)-5])..., ["Points"]),
    ]
    # Function to determine color based on value
    function gradient_highlighter(_, data, i, j)
        if 4 < j <= ncol(data)
            val = if j != ncol(data)
                (isinf(data[i, j].val) ? -1 : data[i, j])
            else
                (isinf(data[i, j].val) ? -1 : data[i, j-1])
            end
            # Map value (assuming 0-1 range) to a color from a scheme
            color = get(colorschemes[:RdYlGn], (val + 1) / 2) # , :extrema)
            hex_color = "#" * hex(color)
            return ["background-color"=>hex_color]
        else
            return false
        end
    end
    hl_data = HtmlHighlighter(
            (data, i, j) -> (ncol(data) > j && j >= 5), # && (data[i, j] > 0.0),
            gradient_highlighter
            # ["color"=>"blue", "font-weight"=>"bold"]
        )
    hl_total = HtmlHighlighter(
            (data, i, j) -> (j == ncol(data)) && (data[i, j] > 0.0),
            ["background-color"=>"red", "font-weight"=>"bold"]
        )
    # hl_percent = HtmlHighlighter(
    #         (data, i, j) -> (j == ncol(data)-1),
    #         ["font-weight"=>"italic"]
    #     )
    # hl_letter = HtmlHighlighter(
    #     (data, i, j) -> (j == ncol(data)), # && (data[i, j] > 0.0),
    #     gradient_highlighter
    #     # ["color"=>"blue", "font-weight"=>"bold"]
    # )
    p = PrettyTable(
        data;
        title           = "$(att.who.codename_long): $(att.who.course.name)",
        subtitle        = "Class Attendance",
        row_labels      = row_labels,
        column_labels   = column_labels,
        summary_row_labels=["Worth", "Due", "Average (Points)", "Average (Percentage)"], # , "S.Dev", "Running Average (Percentage)"],
        summary_rows    = [
            (data, j)->(4 < j <= length(lectures)+4) ? lectures[j - 4].value : "",
            (data, j)->(4 < j <= length(lectures)+4) ? lectures[j - 4].due : "",
            (data, j)->(4 < j <= length(lectures)+4) ? Points.(sum(data[:, j])/length(data[:, j])) : "",
            (data, j)->(4 < j <= length(lectures)+4) ? Percentage.(Points.(sum(data[:, j])/length(data[:, j]))/lectures[j - 4].value) : "",
            # (data, i, j)->,
            # (data, i, j)->
        ],
        style           = HtmlTableStyle(; first_line_column_label = ["font-weight"=>"bold"], column_label = ["color"=>"gray", "font-style"=>"italic"]),
        highlighters    = [hl_data, hl_total],
        table_format    = HtmlTableFormat("""
    .table-wrapper {
    overflow: auto; /* Enables scrolling within the container */
    max-height: 400px; /* Optional: Sets a maximum height for vertical scrolling */
    max-width: 600px; /* Optional: Sets a maximum width for horizontal scrolling */
    }

    /* Make the header row sticky at the top */
    thead th {
    position: sticky;
    top: 0;
    background-color: #f1f1f1; /* Add a background color */
    z-index: 2; /* Ensures headers are above body cells when scrolling vertically */
    }

    /* Make the first column sticky on the left */
    tbody td:first-child,
    tbody th:first-child { /* Use th if your first column cells are headers */
    position: sticky;
    left: 0;
    background-color: #f9f9f9; /* Add a background color */
    z-index: 1; /* Ensures the first column is above other body cells when scrolling horizontally */
    }

    /* Ensure the top-left corner cell (header of the first column) is above everything */
    thead th:first-child {
    z-index: 3; /* Must be the highest z-index */
    }

    /* Optional: Add borders and spacing for better visual separation */
    table {
    border-collapse: separate;
    border-spacing: 0;
    }
    td, th {
    padding: 10px;
    border: 1px solid #ddd;
    }
    """, ""),
        backend         = :html,
        stand_alone     = true
    )
    out = joinpath([pwd(), "gradebook", "build", "attendance.html"])
    mkpath(dirname(out))
    open(out, "w") do io
        write(io, repr(p))
    end
    run(`cmd /c start $out`)
end

function view_attendance(att::Gradebook, identifier::String, lectures::Vector{Assignment})
    number_of_elective_absences = zeros((nrow(att.raw_score), 1))
    for (i, row) in enumerate(eachrow(att.raw_score))
        number_of_elective_absences[i] = count(==(0), collect(select(DataFrame(row), Not(["ID", "Preferred", "Last", "Email"]))[1, :]))
    end
    data = att.raw_score
    insertcols!(data, "Total"=>vec(number_of_elective_absences))
    # insertcols!(data, "Percent"=>Percentage.(vec(final_grades ./ sum(map(x->x.value, collect(assignments)[1:assignment_range_b])))))
    # insertcols!(data, "Letter"=>score2letter.(Percentage.(vec(final_grades ./ sum(map(x->x.value, collect(assignments)[1:assignment_range_b]))))))
    row_labels = [join(collect(row[1:4]), " ") for row in eachrow(data)]
    column_labels = [
        names(data),
        vcat(fill("", 4), map(x->repr(typeof(x).parameters[1])[9:end], lectures[1:ncol(data)-5])..., ["Course"]),
        vcat(fill("", 4), map(x->typeof(x).parameters[2], lectures[1:ncol(data)-5])..., ["Individual"]),
        vcat(fill("", 4), map(x->typeof(x).types[2], lectures[1:ncol(data)-5])..., ["Points"]),
    ]
    # Function to determine color based on value
    function gradient_highlighter(_, matrix, i, j)
        if 4 < j <= ncol(matrix)
            val = if j != ncol(matrix)
                (isinf(matrix[i, j].val) ? -1 : data[i, j])
            else
                (isinf(matrix[i, j].val) ? -1 : data[i, j-1])
            end
            # Map value (assuming 0-1 range) to a color from a scheme
            color = get(colorschemes[:RdYlGn], (val + 1) / 2) # , :extrema)
            hex_color = "#" * hex(color)
            return ["background-color"=>hex_color]
        else
            return false
        end
    end
    hl_data = HtmlHighlighter(
            (data, i, j) -> (ncol(data) > j && j >= 5), # && (data[i, j] > 0.0),
            gradient_highlighter
            # ["color"=>"blue", "font-weight"=>"bold"]
        )
    hl_total = HtmlHighlighter(
            (data, i, j) -> (j == ncol(data)) && (data[i, j] > 0.0),
            ["background-color"=>"red", "font-weight"=>"bold"]
        )
    # hl_percent = HtmlHighlighter(
    #         (data, i, j) -> (j == ncol(data)-1),
    #         ["font-weight"=>"italic"]
    #     )
    # hl_letter = HtmlHighlighter(
    #     (data, i, j) -> (j == ncol(data)), # && (data[i, j] > 0.0),
    #     gradient_highlighter
    #     # ["color"=>"blue", "font-weight"=>"bold"]
    # )
    p = PrettyTable(
        data[occursin.(get_student(att.who.roster, identifier).email, data[!, "Email"]), :];
        title           = "$(att.who.codename_long): $(att.who.course.name)",
        subtitle        = "Class Attendance",
        row_labels      = row_labels,
        column_labels   = column_labels,
        summary_row_labels=["Worth", "Due", "Average (Points)", "Average (Percentage)"], # , "S.Dev", "Running Average (Percentage)"],
        summary_rows    = [
            (matrix, j)->(4 < j <= length(lectures)+4) ? lectures[j - 4].value : "",
            (matrix, j)->(4 < j <= length(lectures)+4) ? lectures[j - 4].due : "",
            (matrix, j)->(4 < j <= length(lectures)+4) ? Points.(sum(data[:, j])/length(data[:, j])) : "",
            (matrix, j)->(4 < j <= length(lectures)+4) ? Percentage.(Points.(sum(data[:, j])/length(data[:, j]))/lectures[j - 4].value) : "",
            # (data, i, j)->,
            # (data, i, j)->
        ],
        style           = HtmlTableStyle(; first_line_column_label = ["font-weight"=>"bold"], column_label = ["color"=>"gray", "font-style"=>"italic"]),
        highlighters    = [hl_data, hl_total],
        table_format    = HtmlTableFormat("""
    .table-wrapper {
    overflow: auto; /* Enables scrolling within the container */
    max-height: 400px; /* Optional: Sets a maximum height for vertical scrolling */
    max-width: 600px; /* Optional: Sets a maximum width for horizontal scrolling */
    }

    /* Make the header row sticky at the top */
    thead th {
    position: sticky;
    top: 0;
    background-color: #f1f1f1; /* Add a background color */
    z-index: 2; /* Ensures headers are above body cells when scrolling vertically */
    }

    /* Make the first column sticky on the left */
    tbody td:first-child,
    tbody th:first-child { /* Use th if your first column cells are headers */
    position: sticky;
    left: 0;
    background-color: #f9f9f9; /* Add a background color */
    z-index: 1; /* Ensures the first column is above other body cells when scrolling horizontally */
    }

    /* Ensure the top-left corner cell (header of the first column) is above everything */
    thead th:first-child {
    z-index: 3; /* Must be the highest z-index */
    }

    /* Optional: Add borders and spacing for better visual separation */
    table {
    border-collapse: separate;
    border-spacing: 0;
    }
    td, th {
    padding: 10px;
    border: 1px solid #ddd;
    }
    """, ""),
        backend         = :html,
        stand_alone     = true
    )
    out = joinpath([pwd(), "gradebook", "build", "attendance.html"])
    mkpath(dirname(out))
    open(out, "w") do io
        write(io, repr(p))
    end
    run(`cmd /c start $out`)
end
