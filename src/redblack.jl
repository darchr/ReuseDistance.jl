@enum Color::UInt Black Red
msb(::Type{T}) where {T<:Integer} = bitrotate(one(T), -1)
msb(::T) where {T<:Integer} = msb(T)

"""
    ProtoNode{T}

Immutable struct for representing a tree node.
The main idea here is that each `ProtoNode` is backed be a vector of such nodes held in
the Red-Black tree itself, and as such has a (relatively) stable address (modulo resizing
of the underlying array, which will have to be dealt with).

Mutation of the `ProtoNode` must happen in conjunction with loads and stores to its
underlying array.

**NOTE**: We store the color of the `ProtoNode` implicitly in the most significant bit of
the `parent` field. As such, care must be taken when accessing that field.
"""
struct ProtoNode{T}
    parent::UInt
    left::UInt
    right::UInt
    key::T
end

"""
    RedBlackTree{T}

A Red-Black tree holding elements of type `T`.
The tree itself is distributed throughout the `nodes` field with the `root` field pointing
to the root of the tree (or set to zero if the tree is empty).

Unused indices are stored in the `free` field and can be used to assign new `ProtoNodes`
to items inserted into the tree.
"""
mutable struct RedBlackTree{T}
    root::Int
    nodes::Vector{ProtoNode{T}}
    free::Vector{Int}
end

function RedBlackTree{T}(len = 10) where {T}
    # Due to our load-store schenanigans, make sure that we only hold `isbitstypes`.
    isbitstype(T) || error("Can only construct a RedBlackTree for `isbitstype` key types!")

    root = zero(Int)
    nodes = Vector{ProtoNode{T}}(undef, len)
    free = collect(reverse(eachindex(nodes)))
    return RedBlackTree{T}(root, nodes, free)
end

"""
    Base.getindex(tree::RedBlackTree) -> Int

Return a free `index` in `tree` that points to a free `ProtoNode`.

Implementation Details
----------------------
If no such index exists, then the underlying `nodes` vector will be doubled in size to
create more nodes.
"""
function Base.getindex(tree::RedBlackTree)
    nodes, free = tree.nodes, tree.free
    if isempty(free)
        currentlength = length(nodes)
        resize!(nodes, 2 * currentlength)
        for i = (currentlength + 1):length(nodes)
            push!(free, i)
        end
    end
    return pop!(free)
end
Base.getindex(tree::RedBlackTree, index::Integer) = tree.nodes[index]

"""
    return!(tree::RedBlackTree, index)

Return `index`'s `ProtoNode` back to `tree` for future reuse.
"""
return!(tree::RedBlackTree, index::Integer) = push!(tree.free, index)

function Base.setindex!(tree::RedBlackTree{T}, k0, index::Integer) where {T}
    k = convert(T, k0)
    ptr = Ptr{T}(pointer(tree, index)) + 3 * sizeof(UInt)
    return unsafe_store!(ptr, k)
end

@inline Base.pointer(tree::RedBlackTree, i::Integer) = pointer(tree.nodes, i)

"""
    RBNode{T}

The `RBNode` is a tree/index that will allow full mutation of the underlying `ProtoNode`.
"""
struct RBNode{T}
    tree::RedBlackTree{T}
    index::UInt
end
RBNode(node::RBNode, index::Integer) = RBNode(node.tree, index)

"""
    getparent(node::RBNode) -> Integer

Return the index of `node`'s parent.

    getparent(tree::RedBlackTree, index::Integer) -> Integer

Return the parent index for the the node at `index` in `tree`.
"""
getparent(node::RBNode) = getparent(node.tree, node.index)
function getparent(tree::RedBlackTree{T}, index::Integer) where {T}
    ptr = pointer(tree, index)
    unmasked = unsafe_load(Ptr{UInt}(ptr))
    return unmasked & ~msb(unmasked)
end

#setparent!(node::RBNode, v) = setparent!(node.tree, v, node.index)
function setparent!(tree::RedBlackTree, index::Integer, v)
    ptr = Ptr{UInt}(pointer(tree, index))
    old = unsafe_load(ptr)
    new = (old & msb(old)) | (v & ~msb(old))
    @show ptr, old, new
    return unsafe_store!(ptr, new)
end

getcolor(node::RBNode) = getcolor(node.tree, node.index)
function getcolor(tree::RedBlackTree{T}, index::Integer) where {T}
    ptr = pointer(tree, index)
    unmasked = unsafe_load(Ptr{UInt}(ptr))
    # N.B.: LLVM is able to elide the bounds check for the enum creation, so we don't
    # need to get fancy with bitcasts or anything like that.
    return Color(bitrotate(unmasked & msb(unmasked), 1))
end

#setcolor!(node::RBNode, color) = setcolor!(node.tree, color, node.index)
function setcolor!(tree::RedBlackTree, index::Integer, color)
    ptr = Ptr{UInt}(pointer(tree, index))
    old = unsafe_load(ptr)
    new = (old & ~msb(old)) | bitrotate(UInt(color) & one(UInt), -1)
    return unsafe_store!(ptr, new)
end

getchild(node::RBNode, direction::Direction) = getchild(node.tree, node.index, direction)
function getchild(tree::RedBlackTree, index::Integer, direction::Direction)
    ptr = pointer(tree, index) + (1 + UInt(direction)) * sizeof(UInt)
    return unsafe_load(Ptr{UInt}(ptr))
end

leftchild(tree::RedBlackTree, index) = getchild(tree, index, Left)
leftchild(node::RBNode) = leftchild(node.tree, node.index)
rightchild(tree::RedBlackTree, index) = getchild(tree, index, Right)
rightchild(node::RBNode) = rightchild(node.tree, node.index)

function setchild!(tree::RedBlackTree, index::Integer, direction::Direction, child)
    ptr = pointer(tree, index) + (1 + UInt(direction)) * sizeof(UInt)
    return unsafe_store!(Ptr{UInt}(ptr), convert(UInt, child))
end
setleft!(tree::RedBlackTree, index, child) = setchild!(tree, index, Left, child)
setleft!(node::RBNode, child) = setleft!(node.tree, node.index, child)
setright!(tree::RedBlackTree, index, child) = setchild!(tree, index, Right, child)
setright!(node::RBNode, child) = setright!(node.tree, node.index, child)

#####
##### Convenience Accessors
#####

function child_direction(tree::RedBlackTree, p::Integer, n::Integer)
    return Direction(leftchild(tree, p) == n)
end

child_direction(tree::RedBlackTree, n::Integer) =
    child_direction(tree, getparent(tree, n), n)

function safeparent(tree::RedBlackTree, n::Integer)
    return iszero(n) ? n : getparent(tree, n)
end

function safegrandparent(tree::RedBlackTree, n::Integer)
    return safeparent(tree, safeparent(tree, n))
end

function sibling(tree::RedBlackTree, n::Integer)
    p = getparent(tree, n)
    return getchild(tree, p, reverse(child_direction(tree, p, n)))
end

function getuncle(tree::RedBlackTree, n::Integer)
    return sibling(tree, getparent(tree, n))
end

function closenephew(tree::RedBlackTree, n::Integer)
    p = getparent(tree, n)
    dir = child_direction(tree, p, n)
    s = getchild(tree, p, reverse(dir))
    return getchild(tree, s, dir)
end

function distantnephew(tree::RedBlackTree, n::Integer)
    p = getparent(tree, n)
    dir = child_direction(tree, p, n)
    s = getchild(tree, p, reverse(dir))
    return getchild(tree, s, reverse(dir))
end

function rotateroot!(tree::RedBlackTree, p::Integer, dir::Direction)
    g = getparent(tree, p)
    s = getchild(tree, p, reverse(dir))
    c = getchild(tree, p, dir)
    setchild!(tree, p, reverse(dir), c)
    iszero(c) || setparent!(tree, c, p)

    setchild!(tree, s, dir, p)
    setparent!(tree, p, s)
    setparent!(tree, s, g)
    if iszero(g)
        tree.root = s
    else
        setchild!(tree, g, child_direction(tree, g, p), s)
    end
    return s
end

rotateleft!(tree::RedBlackTree, n::Integer) = rotateroot!(tree, n, Left)
rotateright!(tree::RedBlackTree, n::Integer) = rotateroot!(tree, n, Right)

#####
##### Insertion
#####

# Now that we have the nitty-gritty accessor implementation out of the way, we can
# get to the actual tree implementation.

"""
    _insert!(tree::RedBlackTree, n, p, direction)

Insert node `n` into the tree as the `direction` child under `p`.
"""
function _insert!(tree::RedBlackTree, n::Integer, p::Integer, direction::Direction)
    setcolor!(tree, n, Red)
    setparent!(tree, n, p)
    setleft!(tree, n, 0)
    setright!(tree, n, 0)

    # There is no parent.
    # `n` is the new root of the tree and insertion is complete.
    if iszero(p)
        tree.root = n
        return nothing
    end

    # Set `n` as the `direction` child of `p`.
    setchild!(tree, p, direction, n)

    # Insertion procedure
    while true
        # Case 1: Parent is Black, insertion is complete.
        if getcolor(tree, p) == Black
            return nothing
        end

        # From now on, we know `getcolor(tree, p) == Red`.
        g = getparent(tree, p)
        if iszero(g)
            # Case 4: `p` is the root and Red.
            setcolor!(tree, p, Black)
            return nothing
        end

        # `p` is `Red` and `g` exists.
        direction = child_direction(tree, n, p)

        # `u` is `n`'s uncle.
        u = getchild(tree, g, reverse(direction))
        if iszero(u) || getcolor(tree, u) == Black
            break
        end

        # Case 2: (Parent and Uncle are Red)
        setcolor!(tree, p, Black)
        setcolor!(tree, u, Black)
        setcolor!(tree, g, Red)

        # `g` becomes the new current node.
        # Iterate one black level higher.
        n = g
        p = getparent!(tree, n)

        # Case 3 - `p` is NULL and insertion is complete.
        iszero(p) && return nothing
    end

    # Case 5: `p` is Red and `u` is black
    if n == getchild(tree, p, reverse(direction))
        rotateroot!(tree, p, direction)
        n = p
        p = getchild(tree, g, direction)
    end

    # Case 6: `p` is Red, `u` is black, and `n` is the outer grandchild of `g`.
    rotateroot!(tree, g, reverse(direction))
    setcolor!(tree, p, Black)
    setcolor!(tree, g, Red)
    return nothing
end

