# using Plots; gr()
using RecipesBase

# default(
#     fontfamily="Computer Modern",
#     linewidth=1,
#     framestyle=:box,
#     label=nothing,
#     grid=false)
# scalefontsizes(1.3)

@userplot ViewGradebook
# @userplot ViewAttendance

@recipe f(::Type{Gradebook}, gb::Gradebook) = gb.df