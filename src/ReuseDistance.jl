module ReuseDistance

export Node, Treap, search

# deps
import AbstractTrees
import ProgressMeter

# implementation
include("treap.jl")

function reuse(itr)
    treap = Treap{Tuple{Int,eltype(itr)}}()
    lastuse = Dict{eltype(itr),Int}()
    histogram = Dict{Int,Int}()

    for (t, i) in enumerate(itr)
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
    return histogram
end

#####
##### Naive Implementation
#####

function reuse_naive(v::AbstractVector{T}) where {T}
    lastuse = Dict{T,Int}()
    counts = Set{T}()
    histogram = Dict{Int,Int}()

    ProgressMeter.@showprogress 1 for (t, i) in enumerate(v)
        lasttime = get(lastuse, i, t)
        d = -1
        if lasttime != t
            empty!(counts)
            for u in view(v, (lasttime + 1):(t - 1))
                push!(counts, u)
            end
            d = length(counts)
        end
        histogram[d] = 1 + get(histogram, d, 0)
        lastuse[i] = t
    end
    return histogram
end

function gramsequal(a, b)
    passed = true
    for (k, v) in a
        if haskey(b, k)
            passed &= (b[k] == v)
        else
            passed = false
        end
    end

    for (k, v) in b
        if haskey(a, k)
            passed &= (a[k] == v)
        else
            passed = false
        end
    end
    return passed
end

end
