#####
##### PushVector
#####

mutable struct PushVector{T} <: AbstractVector{T}
    data::Vector{T}
    len::Int
end

PushVector{T}() where {T} = PushVector{T}(T[], 0)
Base.size(v::PushVector) = (v.len,)
maxlength(v::PushVector) = length(v.data)

Base.IndexStyle(::PushVector) = Base.IndexLinear()
Base.@propagate_inbounds function Base.getindex(A::PushVector, i::Int)
    @boundscheck checkbounds(A, i)
    return @inbounds(A.data[i])
end

Base.@propagate_inbounds function Base.setindex!(A::PushVector, v, i::Int)
    @boundscheck checkbounds(A, i)
    return @inbounds(A.data[i] = v)
end

function Base.push!(A::PushVector, v)
    len = length(A)
    if len < maxlength(A)
        @inbounds(A.data[len + 1] = v)
    else
        push!(A.data, v)
    end
    A.len += 1
    return A
end

Base.empty!(A::PushVector) = (A.len = 0)

#####
##### Node
#####

@enum Direction::UInt8 Left Right
mutable struct Node{T}
    key::T
    priority::UInt
    nchildren::Int
    left::Union{Nothing,Node{T}}
    right::Union{Nothing,Node{T}}

    function Node{T}(key::T) where {T}
        priority = rand(UInt)
        return new{T}(key, priority, 1, nothing, nothing)
    end
end

Node(key::T) where {T} = Node{T}(key)

function Base.show(io::IO, node::Node{T}) where {T}
    hasleft = lchild(node) !== nothing
    hasright = rchild(node) !== nothing
    print(
        io,
        "Node{$T}($(node.key), $(node.priority), $(node.nchildren), $hasleft, $hasright)",
    )
    return nothing
end

mutable struct Treap{T}
    root::Union{Nothing,Node{T}}
    path::PushVector{Tuple{Node{T},Direction}}
    nodebuffer::Vector{Node{T}}
end
Treap{T}() where {T} = Treap{T}(nothing, PushVector{Tuple{Node{T},Direction}}(), Node{T}[])

lchild(n::Node) = n.left
rchild(n::Node) = n.right
hasleft(n::Node) = lchild(n) !== nothing
hasright(n::Node) = rchild(n) !== nothing

@inline setleft!(n::Node, v::Node) = (n.left = v)
@inline setleft!(n::Node) = (n.left = nothing)
@inline setright!(n::Node, v::Node) = (n.right = v)
@inline setright!(n::Node) = (n.right = nothing)

# Compute number of children.
function update!(node::Node)
    subtree = 1
    left = lchild(node)
    left === nothing || (subtree += left.nchildren)
    right = rchild(node)
    right === nothing || (subtree += right.nchildren)
    node.nchildren = subtree
    return subtree
end

function rotate_right!(root::Node)
    newroot = lchild(root)
    newroot === nothing && return root
    right = rchild(newroot)
    right === nothing ? setleft!(root) : setleft!(root, right)
    setright!(newroot, root)
    update!(root)
    update!(newroot)
    return newroot
end

function rotate_left!(root::Node)
    newroot = rchild(root)
    newroot === nothing && return root
    left = lchild(newroot)
    left === nothing ? setright!(root) : setright!(root, left)
    setleft!(newroot, root)
    update!(root)
    update!(newroot)
    return newroot
end

function search(root::Node, key)
    root.key == key && return root
    next = (key < root.key) ? lchild(root) : rchild(root)
    return next === nothing ? nothing : search(next, key)
end
Base.in(key, root::Node) = (search(root, key) !== nothing)
Base.haskey(root::Node, key) = (search(root, key) !== nothing)

function nchildren(root::Node, key)
    count = 0
    while true
        if root.key == key
            right = rchild(root)
            if right !== nothing
                count += right.nchildren
            end
            return count
        elseif key < root.key
            count += 1
            right = rchild(root)
            if right !== nothing
                count += right.nchildren
            end
            next = lchild(root)
        else
            next = rchild(root)
        end
        next === nothing && error()
        root = next
    end
end

#####
##### insertion
#####

# Node only method
function Base.insert!(root::Node, node)
    if node.key < root.key
        _left = lchild(root)
        left = setleft!(root, _left === nothing ? node : insert!(_left, node))
        if left.priority > root.priority
            root = rotate_right!(root)
        end
    else
        _right = rchild(root)
        right = setright!(root, _right === nothing ? node : insert!(_right, node))
        if right.priority > root.priority
            root = rotate_left!(root)
        end
    end
    update!(root)
    return root
end

# Using treap auxiliary data structures
function insertdown!(treap::Treap, node)
    _current = root(treap)
    _current === nothing && return nothing
    current = _current
    path = treap.path
    empty!(path)
    while true
        if node.key < current.key
            push!(path, (current, Left))
            next = lchild(current)
        else
            push!(path, (current, Right))
            next = rchild(current)
        end
        next === nothing && return nothing
        current = next
    end
end

function insertup!(treap::Treap, node::Node)
    path = treap.path
    i = length(path)
    @inbounds while i > 0
        root, direction = path[i]
        if direction == Left
            left = setleft!(root, node)
            left.priority > root.priority ? rotate_right!(root) : break
        else
            right = setright!(root, node)
            right.priority > root.priority ? rotate_left!(root) : break
        end
        update!(node)
        i -= 1
    end

    # If the path is empty, then we percolated updates all the way to the root and
    # need to update the "treap's" root.
    # Otherwise, we need to bookkeep the children numbers on the path we visited.
    if iszero(i)
        treap.root = node
    else
        @inbounds for j in Base.OneTo(i)
            root, _ = path[j]
            root.nchildren += 1
        end
    end
    return treap
end

#####
##### deletion
#####

macro _split(sym, f)
    return esc(quote
        if $sym !== nothing
            _tmp = delete!($sym, key)
            _tmp === nothing ? $f(root) : $f(root, _tmp)
        end
    end)
end

function Base.delete!(root::Node{T}, key::T) where {T}
    left = lchild(root)
    right = rchild(root)
    # Branch left if possible
    if (key < root.key)
        @_split left setleft!
        # Branch right if possible
    elseif (key > root.key)
        @_split right setright!
        # Key is at node, try removal of left or right.
    elseif left === nothing
        root = right
    elseif right === nothing
        root = left
        # Node has two children, rotate and move down.
    elseif left.priority < right.priority
        old = root
        root = rotate_left!(root)
        _tmp = delete!(old, key)
        _tmp === nothing ? setleft!(root) : setleft!(root, _tmp)
    else
        old = root
        root = rotate_right!(root)
        _tmp = delete!(old, key)
        _tmp === nothing ? setright!(root) : setright!(root, _tmp)
    end
    root === nothing || update!(root)
    return root
end

function deletefind!(treap::Treap, current::Node, key)
    path = treap.path
    empty!(path)
    while true
        current.key == key && return current
        if key < current.key
            push!(path, (current, Left))
            next = lchild(current)
        else
            push!(path, (current, Right))
            next = rchild(current)
        end
        next === nothing && return current
        current = next
    end
end

function deletedown!(treap::Treap, root, node)
    updateroot = (node == root)
    path = treap.path
    if isempty(path)
        treap.root = nothing
        return nothing
    end

    # find a replacement node
    while true
        parent, direction = @inbounds(path[end])
        left = lchild(node)
        right = rchild(node)

        # Easy path, both children are nothing, we just need to
        @show (parent, direction, left, right, node)
        if left === nothing
            if right === nothing
                direction === Left ? setleft!(parent) : setright!(parent)
                break
            else
                direction === Left ? setleft!(parent, right) : setright!(parent, right)
                setright!(node)
            end
        elseif right === nothing
            direction === Left ? setleft!(parent, left) : setright!(parent, left)
            setleft!(node)
        elseif left.priority < right.priority
            # Right will become the successor
            rotate_left!(node)
            direction === Left ? setleft!(parent, right) : setright!(parent, right)
            push!(path, (right, Left))
        else
            rotate_right!(node)
            direction === Left ? setleft!(parent, left) : setright!(parent, left)
            push!(path, (left, Right))
        end
    end

    for (n, _) in path
        n.nchildren -= 1
    end
    if updateroot
        n = path[begin]
        treap.root = n
    end
    return nothing
end

#####
##### misc
#####

function traverse(f::F, root::Node) where {F}
    left = lchild(root)
    if left !== nothing
        traverse(f, left)
    end
    f(root)
    right = rchild(root)
    if right !== nothing
        traverse(f, right)
    end
    return nothing
end

function list(root::Node{T}) where {T}
    v = T[]
    traverse(x -> push!(v, x.key), root)
    return v
end

#####
##### Treap
#####

function Base.length(treap::Treap)
    base = root(treap)
    return base === nothing ? 0 : base.nchildren
end
root(treap::Treap) = treap.root

function nchildren(treap::Treap, key)
    base = root(treap)
    base === nothing && return -1
    return nchildren(base, key)
end

function Base.in(key0, treap::Treap{T}) where {T}
    node = root(treap)
    node === nothing && return false
    return in(convert(T, key0), node)
end

function unsafe_push!(treap::Treap{T}, key0) where {T}
    key = convert(T, key0)
    node = Node(key)

    base = root(treap)
    if base === nothing
        treap.root = node
        return treap
    end

    insertdown!(treap, node)
    insertup!(treap, node)
    # treap.root = insert!(base, node)
    return treap
end

function Base.push!(treap::Treap{T}, key0) where {T}
    key = convert(T, key0)
    in(key, treap) || unsafe_push!(treap, key)
    return treap
end

function Base.delete!(treap::Treap{T}, key0) where {T}
    key = convert(T, key0)
    in(key, treap) || return false
    base = root(treap)
    base === nothing && return false
    # node = deletefind!(treap, base, key)
    # deletedown!(treap, base, node)
    treap.root = delete!(base, key)
    return true
end

#####
##### Treap verification
#####

function istree(treap::Treap)
    base = root(treap)
    return base === nothing ? true : istree(base)
end
function istree(node::Node{T}) where {T}
    v = T[]
    traverse(node) do n
        push!(v, n.key)
    end
    return issorted(v)
end

function isheap(treap::Treap)
    base = root(treap)
    return base === nothing ? true : isheap(base)
end
function isheap(node::Node)
    passed = true
    left = lchild(node)
    if left !== nothing
        passed &= isheap(left)
        passed &= (node.priority > left.priority)
    end
    right = rchild(node)
    if right !== nothing
        passed &= isheap(right)
        passed &= (node.priority > right.priority)
    end

    return passed
end

#####
##### AbstractTrees
#####

function AbstractTrees.children(node::Node)
    if hasleft(node)
        if hasright(node)
            return (lchild(node), rchild(node))
        else
            return (lchild(node),)
        end
    else
        if hasright(node)
            return (rchild(node),)
        else
            return ()
        end
    end
end

AbstractTrees.printnode(io::IO, node::Node) = print(io, node.key)

