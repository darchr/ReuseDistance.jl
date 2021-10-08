using ReuseDistance
using Test

@testset "Testing Node" begin
    Node = ReuseDistance.Node
    lchild = ReuseDistance.lchild
    rchild = ReuseDistance.rchild

    #####
    ##### rotate_right!
    #####

    # only left child
    node = Node(10)
    left = Node(5)
    ReuseDistance.setleft!(node, left)

    @test lchild(node) === left
    @test rchild(node) === nothing

    newnode = ReuseDistance.rotate_right!(node)
    @test newnode === left
    @test rchild(left) === node
    @test lchild(left) === nothing
    @test rchild(node) === nothing
    @test lchild(node) === nothing

    # two children
    node = Node(10)
    left = Node(5)
    right = Node(15)
    ReuseDistance.setleft!(node, left)
    ReuseDistance.setright!(node, right)

    @test lchild(node) === left
    @test rchild(node) === right

    newnode = ReuseDistance.rotate_right!(node)
    @test newnode === left
    @test rchild(left) === node
    @test lchild(left) === nothing
    @test rchild(node) === right
    @test lchild(node) === nothing

    # hierarchy
    node = Node(10)
    left = Node(5)
    leftleft = Node(1)
    leftright = Node(7)

    right = Node(20)

    ReuseDistance.setleft!(node, left)
    ReuseDistance.setleft!(left, leftleft)
    ReuseDistance.setright!(left, leftright)

    ReuseDistance.setright!(node, right)

    newnode = ReuseDistance.rotate_right!(node)
    @test newnode === left
    @test rchild(left) === node
    @test lchild(left) === leftleft

    @test rchild(node) === right
    @test lchild(node) === leftright

    #####
    ##### rotate_left!
    #####

    # only right child
    node = Node(10)
    right = Node(15)
    ReuseDistance.setright!(node, right)

    @test lchild(node) === nothing
    @test rchild(node) === right

    newnode = ReuseDistance.rotate_left!(node)
    @test newnode === right
    @test rchild(right) === nothing
    @test lchild(right) === node
    @test rchild(node) === nothing
    @test lchild(node) === nothing

    # two children
    node = Node(10)
    left = Node(5)
    right = Node(15)
    ReuseDistance.setleft!(node, left)
    ReuseDistance.setright!(node, right)

    @test lchild(node) === left
    @test rchild(node) === right

    newnode = ReuseDistance.rotate_left!(node)
    @test newnode === right
    @test rchild(right) === nothing
    @test lchild(right) === node
    @test rchild(node) === nothing
    @test lchild(node) === left

    # hierarchy
    node = Node(10)
    left = Node(5)

    right = Node(20)
    rightleft = Node(15)
    rightright = Node(25)

    ReuseDistance.setleft!(node, left)

    ReuseDistance.setright!(node, right)
    ReuseDistance.setleft!(right, rightleft)
    ReuseDistance.setright!(right, rightright)

    newnode = ReuseDistance.rotate_left!(node)
    @test newnode === right
    @test rchild(right) === rightright
    @test lchild(right) === node

    @test rchild(node) === rightleft
    @test lchild(node) === left
end

