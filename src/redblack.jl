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
    root::UInt
    nodes::Vector{ProtoNode{T}}
    free::Vector{Int}
end

Base.length(tree::RedBlackTree) = length(tree.nodes) - length(tree.free)

function RedBlackTree{T}(len::Integer = 10) where {T}
    # Due to our load-store schenanigans, make sure that we only hold `isbitstypes`.
    isbitstype(T) || error("Can only construct a RedBlackTree for `isbitstype` key types!")

    root = zero(Int)
    nodes = Vector{ProtoNode{T}}(undef, max(one(len), len))
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
Base.getindex(tree::RedBlackTree, index::Integer) = tree.nodes[index].key

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
    getparent(tree::RedBlackTree, index::Integer) -> Integer

Return the parent index for the the node at `index` in `tree`.
"""
function getparent(tree::RedBlackTree{T}, index::Integer) where {T}
    ptr = pointer(tree, index)
    unmasked = unsafe_load(Ptr{UInt}(ptr))
    return unmasked & ~msb(unmasked)
end

function setparent!(tree::RedBlackTree, index::Integer, v)
    ptr = Ptr{UInt}(pointer(tree, index))
    old = unsafe_load(ptr)
    new = (old & msb(old)) | (v & ~msb(old))
    return unsafe_store!(ptr, new)
end

function getcolor(tree::RedBlackTree{T}, index::Integer) where {T}
    ptr = pointer(tree, index)
    unmasked = unsafe_load(Ptr{UInt}(ptr))
    # N.B.: LLVM is able to elide the bounds check for the enum creation, so we don't
    # need to get fancy with bitcasts or anything like that.
    return Color(bitrotate(unmasked & msb(unmasked), 1))
end

function setcolor!(tree::RedBlackTree, index::Integer, color)
    ptr = Ptr{UInt}(pointer(tree, index))
    old = unsafe_load(ptr)
    new = (old & ~msb(old)) | bitrotate(UInt(color) & one(UInt), -1)
    return unsafe_store!(ptr, new)
end

function getchild(tree::RedBlackTree, index::Integer, direction::Direction)
    ptr = pointer(tree, index) + (1 + UInt(direction)) * sizeof(UInt)
    return unsafe_load(Ptr{UInt}(ptr))
end

leftchild(tree::RedBlackTree, index) = getchild(tree, index, Left)
rightchild(tree::RedBlackTree, index) = getchild(tree, index, Right)

function setchild!(tree::RedBlackTree, index::Integer, direction::Direction, child)
    ptr = pointer(tree, index) + (1 + UInt(direction)) * sizeof(UInt)
    return unsafe_store!(Ptr{UInt}(ptr), convert(UInt, child))
end
setleft!(tree::RedBlackTree, index, child) = setchild!(tree, index, Left, child)
setright!(tree::RedBlackTree, index, child) = setchild!(tree, index, Right, child)

isred(tree::RedBlackTree, n::Integer) = !iszero(n) && (getcolor(tree, n) == Red)

#####
##### Convenience Accessors
#####

function child_direction(tree::RedBlackTree, p::Integer, n::Integer)
    return Direction(leftchild(tree, p) != n)
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
    c = getchild(tree, s, dir)
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

# Now that we have the nitty-gritty accessor implementation out of the way, we can
# get to the actual tree implementation.
@enum Findings::UInt8 NotFoundLeft NotFoundRight Found
function search(tree::RedBlackTree{T}, key::T) where {T}
    n = tree.root
    lastn = n
    direction = Left

    while !iszero(n)
        v = tree[n]
        key == v && return n, Found
        direction = Direction(v < key)
        lastn, n = n, getchild(tree, n, direction)
    end
    return lastn, Base.bitcast(Findings, direction)
end

function Base.haskey(tree::RedBlackTree{T}, k0) where {T}
    _, status = search(tree, convert(T, k0))
    return status == Found
end
Base.in(k, tree::RedBlackTree) = haskey(tree, k)

#####
##### Insertion
#####

function Base.push!(tree::RedBlackTree{T}, k::T) where {T}
    p, status = search(tree, k)
    status == Found && return tree

    # Create a new node and finish inserting
    n = tree[]
    tree[n] = k
    _insert!(tree, n, p, Base.bitcast(Direction, status))
    return tree
end

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
    local g
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
        direction = child_direction(tree, g, p)

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
        p = getparent(tree, n)

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

#####
##### Deletion
#####

function swap_successor!(tree::RedBlackTree, n::Integer, m::Integer)
    # Swap colors
    cₙ = getcolor(tree, n)
    cₘ = getcolor(tree, m)
    setcolor!(tree, m, cₙ)
    setcolor!(tree, n, cₘ)

    # Swap Left Children
    lₙ = leftchild(tree, n)
    lₘ = leftchild(tree, m)
    setleft!(tree, n, lₘ)
    iszero(lₘ) || setparent!(tree, lₘ, n)
    setleft!(tree, m, lₙ)
    iszero(lₙ) || setparent!(tree, lₙ, m)

    # Need to be more careful with right children and parents for the case where
    # `m` is the right child of `n`
    if n == getparent(tree, m)
        ##println("    Successor is child")
        p = getparent(tree, n)
        setparent!(tree, m, p)
        iszero(p) || setchild!(tree, p, child_direction(tree, p, n), m)

        rₘ = rightchild(tree, m)
        setright!(tree, n, rₘ)
        iszero(rₘ) || setparent!(tree, rₘ, n)
        setparent!(tree, n, m)
        setright!(tree, m, n)
    else
        # Swap parents
        #println("    Successor is not child")
        pₙ = getparent(tree, n)
        pₘ = getparent(tree, m)
        setparent!(tree, m, pₙ)
        iszero(pₙ) || setchild!(tree, pₙ, child_direction(tree, pₙ, n), m)
        setparent!(tree, n, pₘ)
        setchild!(tree, pₘ, child_direction(tree, pₘ, m), n)

        # Swap right children
        rₙ = rightchild(tree, n)
        rₘ = rightchild(tree, m)
        setright!(tree, n, rₘ)
        iszero(rₘ) || setparent!(tree, rₘ, n)
        setright!(tree, m, rₙ)
        setparent!(tree, rₙ, m)
    end
    n == tree.root && (tree.root = m)
    return nothing
end

function Base.findmin(tree::RedBlackTree, n::Integer)
    while true
        m = leftchild(tree, n)
        iszero(m) && return n
        n = m
    end
end

function _delete!(tree::RedBlackTree, n::Integer)
    # Case 1: `n` is the only node in the tree
    if n == tree.root && length(tree) == 1
        tree.root = 0
        return nothing
    end

    # Case 2: Do we have two non-NIL children?
    left = leftchild(tree, n)
    right = rightchild(tree, n)
    if !iszero(left) && !iszero(right)
        replacement = findmin(tree, right)
        swap_successor!(tree, n, replacement)

        # Update `left` and `right`, then fall through to case 3.
        left = leftchild(tree, n)
        right = rightchild(tree, n)
    end

    # Case 3: `n` now has at most one non-NIL child.
    color = getcolor(tree, n)
    # If `n` is Red - then it has no children.
    # Else if `n` is black, is it has a child, it must be a red child.
    # Replace `node` with its child and color the child `Black`.
    p = getparent(tree, n)
    if color == Red
        setchild!(tree, p, child_direction(tree, p, n), 0)
        return nothing
    elseif iszero(left) && iszero(right)
        _delete_complex!(tree, n)
        return nothing
    else
        m = iszero(left) ? right : left
        setcolor!(tree, m, Black)
        setparent!(tree, m, p)
        if iszero(p)
            tree.root = m
        else
            setchild!(tree, p, child_direction(tree, p, n), m)
        end
        return nothing
    end
end

function _delete_complex!(tree::RedBlackTree, n::Integer)
    p = getparent(tree, n)
    direction = child_direction(tree, p, n)
    setchild!(tree, p, direction, 0)

    local s, d, c
    while true
        # s: sibling
        # d: distant nephew
        # c: close nephew
        s = getchild(tree, p, reverse(direction))
        d = getchild(tree, s, reverse(direction))
        c = getchild(tree, s, direction)

        getcolor(tree, s) == Red && @goto case_d3
        isred(tree, d) && @goto case_d6
        isred(tree, c) && @goto case_d5
        getcolor(tree, p) == Red && @goto case_d4

        # All of p, c, s, d are Black
        setcolor!(tree, s, Red)
        n = p
        p = getparent(tree, n)
        iszero(p) && return nothing
        direction = child_direction(tree, p, n)
    end

    @label case_d3
    rotateroot!(tree, p, direction)
    setcolor!(tree, p, Red)
    setcolor!(tree, s, Black)
    s = c
    d = getchild(tree, s, reverse(direction))
    isred(tree, d) && @goto case_d6
    c = getchild(tree, s, direction)
    isred(tree, c) && @goto case_d5

    @label case_d4
    setcolor!(tree, s, Red)
    setcolor!(tree, p, Black)
    return nothing

    @label case_d5
    rotateroot!(tree, s, reverse(direction))
    setcolor!(tree, s, Red)
    setcolor!(tree, c, Black)
    d = s
    s = c

    @label case_d6
    rotateroot!(tree, p, direction)
    setcolor!(tree, s, getcolor(tree, p))
    setcolor!(tree, p, Black)
    setcolor!(tree, d, Black)
    return nothing
end

function Base.delete!(tree::RedBlackTree{T}, k0) where {T}
    k = convert(T, k0)
    n, status = search(tree, k)
    if status == Found
        _delete!(tree, n)
        push!(tree.free, n)
        return true
    end
    return false
end

#####
##### misc
#####

function traverse(f::F, tree::RedBlackTree) where {F}
    root = tree.root
    iszero(root) || traverse(f, tree, tree.root)
    return nothing
end

function traverse(f::F, tree::RedBlackTree, i) where {F}
    left = leftchild(tree, i)
    iszero(left) || traverse(f, tree, left)
    f(i)
    right = rightchild(tree, i)
    iszero(right) || traverse(f, tree, right)
    return nothing
end

function istree(tree::RedBlackTree{T}) where {T}
    v = T[]
    seen = Set{Int}()
    traverse(tree) do i
        if in(i, seen)
            error("Tree is broken!")
        end
        push!(seen, i)
        push!(v, tree[i])
    end
    return issorted(v)
end

function no_red_children(tree::RedBlackTree)
    passed = true
    traverse(tree) do i
        if getcolor(tree, i) == Red
            left = leftchild(tree, i)
            right = rightchild(tree, i)
            passed &= (iszero(left) || getcolor(tree, left) == Black)
            passed &= (iszero(right) || getcolor(tree, right) == Black)
        end
    end
    return passed
end

"""
    pathsequal(tree::RedBlackTree)

Check that all paths to all NIL decendents for each node in `tree` passes through the same
number of black nodes.
"""
function pathsequal(tree::RedBlackTree)
    root = tree.root
    iszero(root) && return true
    return pathlength(tree, tree.root) != 0
end

function pathlength(tree::RedBlackTree, i)
    left = leftchild(tree, i)
    right = rightchild(tree, i)
    if iszero(left) && iszero(right)
        return Int(getcolor(tree, i) == Black) + 1
    else
        left_length = iszero(left) ? 1 : pathlength(tree, left)
        right_length = iszero(right) ? 1 : pathlength(tree, right)

        # We've failed - abort!
        if iszero(left_length) || iszero(right_length) || left_length != right_length
            println("Node: $i - Left: $left_length, Right: $right_length")
            return 0
        else
            return left_length + Int(getcolor(tree, i) == Black)
        end
    end
end

function validate(tree::RedBlackTree)
    return istree(tree) && no_red_children(tree) && pathsequal(tree)
end

#####
##### Abstract Trees
#####

struct TreeIndex{T,I}
    tree::RedBlackTree{T}
    index::I
end

AbstractTrees.print_tree(tree::RedBlackTree; kw...) =
    AbstractTrees.print_tree(TreeIndex(tree, tree.root); kw...)

function AbstractTrees.children(ti::TreeIndex)
    left, right = leftchild(ti.tree, ti.index), rightchild(ti.tree, ti.index)
    return [TreeIndex(ti.tree, i) for i in (left, right) if !iszero(i)]
end

AbstractTrees.printnode(io::IO, ti::TreeIndex) =
    print(io, "$(ti.tree[ti.index]) ($(ti.index) - $(getcolor(ti.tree, ti.index)))")

