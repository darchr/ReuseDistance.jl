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
    print(io, "Node{$T}($(node.key), $(node.priority), $(node.nchildren), $hasleft, $hasright)")
    return nothing
end

lchild(n::Node) = n.left
rchild(n::Node) = n.right
hasleft(n::Node) = lchild(n) !== nothing
hasright(n::Node) = rchild(n) !== nothing

@inline setleft!(n::Node, v = nothing) = (v === nothing) ? (n.left = nothing) : (n.left = v)
@inline setright!(n::Node, v = nothing) = (v === nothing) ? (n.right = nothing) : (n.right = v)

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

function Base.delete!(root::Node{T}, key::T) where {T}
    left = lchild(root)
    right = rchild(root)
    # Branch left if possible
    if (key < root.key)
        if left !== nothing
            _tmp = delete!(left, key)
            _tmp === nothing ? setleft!(root) : setleft!(root, _tmp)
        end
    # Branch right if possible
    elseif (key > root.key)
        if right !== nothing
            _tmp = delete!(right, key)
            _tmp === nothing ? setright!(root) : setright!(root, _tmp)
        end
    # Key is at node, try removal of left or right.
    elseif left === nothing
        root = right
    elseif right === nothing
        root = left
    # Node has two children, rotate and move down.
    elseif left.priority < right.priority
        root = rotate_left!(root)
        newleft = lchild(root)
        if newleft !== nothing
            _tmp = delete!(newleft, key)
            _tmp === nothing ? setleft!(root) : setleft!(root, _tmp)
        end
    else
        root = rotate_right!(root)
        newright = rchild(root)
        if newright !== nothing
            _tmp = delete!(newright, key)
            _tmp === nothing ? setright!(root) : setright!(root, _tmp)
        end
    end
    root === nothing || update!(root)
    return root
end

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

mutable struct Treap{T}
    root::Union{Nothing,Node{T}}
end

Treap{T}() where {T} = Treap{T}(nothing)
function Base.length(treap::Treap)
    base = root(treap)
    return base === nothing ? -1 : base.nchildren
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

    treap.root = insert!(base, node)
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

