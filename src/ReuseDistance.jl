module ReuseDistance

mutable struct Node{T}
    key::T
    priority::UInt
    left::Node{T}
    right::Node{T}

    function Node{T}(key::T) where {T}
        priority = rand(UInt)
        node = new{T}(key, priority)
        node.left = node
        node.right = node
        return node
    end
end

Node(key::T) where {T} = Node{T}(key)

function Base.show(io::IO, node::Node{T}) where {T}
    hasleft = lchild(node) !== nothing
    hasright = rchild(node) !== nothing
    print(io, "Node{$T}($(node.key), $(node.priority), $hasleft, $hasright)")
    return nothing
end

_lchild(n::Node) = n.left
_rchild(n::Node) = n.right
hasleft(n::Node) = _lchild(n) !== n
hasright(n::Node) = _rchild(n) !== n

lchild(n::Node) = (n.left === n) ? nothing : _lchild(n)
rchild(n::Node) = (n.right === n) ? nothing : _rchild(n)

setleft!(n::Node, v) = (n.left = v)
clearleft!(n::Node) = (n.left = n)
setright!(n::Node, v) = (n.right = v)
clearright!(n::Node) = (n.right = n)

function rotate_right!(root::Node)
    newroot = _lchild(root)
    hasright(newroot) ? setleft!(root, _rchild(newroot)) : clearleft!(root)
    setright!(newroot, root)
    return newroot
end

function rotate_left!(root::Node)
    newroot = _rchild(root)
    hasleft(newroot) ? setright!(root, _lchild(newroot)) : clearright!(root)
    setleft!(newroot, root)
    return newroot
end

function Base.insert!(root::Node, node)
    if node.key < root.key
        left = lchild(root)
        left = setleft!(root, left === nothing ? node : insert!(left, node))

        if left.priority > root.priority
            root = rotate_right!(root)
        end
    else
        right = rchild(root)
        right = setright!(root, right === nothing ? node : insert!(right, node))

        if right.priority > root.priority
            root = rotate_left!(root)
        end
    end
    return root
end

function Base.delete!(root)
    if lchild(root) === nothing
        root = rchild(root)
    elseif rchild(root) === nothing
        root = lchild(root)
    elseif lchild(root).priority < rchild(root).priority
        root = rotate_left!(root)
        setleft!(root, delete!(lchild(root)))
    else
        root = rotate_right!(root)
        setright!(root, delete!(rchild(root)))
    end
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

#####
##### Treap
#####

mutable struct Treap{T}
    root::Union{Nothing,Node{T}}
    count::Int
end

root(treap::Treap) = treap.root
function Base.push!(treap::T, key0) where {T}
    key = convert(T, key0)
    node = Node(key)
    treap.root = insert!(root(treap), node)
    treap.count += 1
    return treap
end

#####
##### Treap verification
#####

istree(treap::Treap) = istree(root(treap))
function istree(node::Node{T}) where {T}
    v = T[]
    traverse(node) do n
        push!(v, n.key)
    end
    return issorted(v)
end

isheap(treap::Treap) = isheap(root(treap))
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

end
