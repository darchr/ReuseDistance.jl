module ReuseDistance

export Node, Treap, search

# deps
import AbstractTrees
import ProgressMeter
import Setfield: @set

# implementation
include("reference.jl")
include("treap.jl")
include("redblack.jl")

function reuse(itr)
    treap = Treap{Tuple{Int,eltype(itr)}}()
    lastuse = Dict{eltype(itr),Int}()
    histogram = Dict{Int,Int}()

    ProgressMeter.@showprogress 1 for (t, i) in enumerate(itr)
        lasttime = get(lastuse, i, t)
        key = (lasttime, i)
        d = -1
        if lasttime != t
            d = nchildren(treap, key)
            delete!(treap, key)
        end
        histogram[d] = 1 + get(histogram, d, 0)
        push!(treap, (t, i))
        lastuse[i] = t
    end
    @assert istree(treap)
    @assert isheap(treap)
    return histogram
end

# function moveend!(d)
#     m = maximum(keys(d))
#     d[m+1] = d[-1]
#     delete!(d, -1)
#     return nothing
# end
#
# """
#     transform(dict)
# Transform a histogram `dict` into a vector representation.
# """
# function transform(dict)
#     ks = sort(collect(keys(dict)))
#
#     array = Vector{valtype(dict)}()
#     sizehint!(array, last(ks) - first(ks))
#
#     lastkey = first(ks) - 1
#     for k in ks
#         # Append an appropriate number of zeros to the last
#         for _ in 1:(k - lastkey - 1)
#             push!(array, zero(valtype(dict)))
#         end
#         push!(array, dict[k])
#         lastkey = k
#     end
#     return array
# end
#
# """
#     cdf(x) -> Vector
# Return the `cdf` of `x`.
# """
# function cdf(x)
#     v = x ./ sum(x)
#     for i in 2:length(v)
#         v[i] = v[i] + v[i-1]
#     end
#     return v
# end
#
# function cdf(x::Dict)
#     d = copy(x)
#     moveend!(d)
#     return cdf(transform(d))
# end

end
