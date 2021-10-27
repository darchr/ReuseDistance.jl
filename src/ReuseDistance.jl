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
    #treap = Treap{Tuple{Int,eltype(itr)}}()
    treap = RedBlackTree{Tuple{Int,eltype(itr)}}()
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
    # @assert isheap(treap)
    return histogram
end

end
