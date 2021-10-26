@testset "Testing RedBlack Tree" begin
    @test reverse(ReuseDistance.Left) == ReuseDistance.Right
    @test reverse(ReuseDistance.Right) == ReuseDistance.Left

    @testset "Testing Accessors" begin
        # Initialize the tree with length zero.
        # This will test the corner case handling of setting the minimum node vector
        # length to 1 AND test the length extension logic.
        tree = ReuseDistance.RedBlackTree{Int}(0)

        # Get a new index from the tree
        n = tree[]
        @test n == 1
        tree[n] = 500
        @test tree[n] == 500

        # Null all other pointer fields
        ReuseDistance.setcolor!(tree, n, ReuseDistance.Black)
        ReuseDistance.setparent!(tree, n, 0)
        ReuseDistance.setleft!(tree, n, 0)
        ReuseDistance.setright!(tree, n, 0)

        @test ReuseDistance.getcolor(tree, n) == ReuseDistance.Black
        @test ReuseDistance.getparent(tree, n) == 0
        @test ReuseDistance.leftchild(tree, n) == 0
        @test ReuseDistance.rightchild(tree, n) == 0

        # Setting the color to `Red` should not affect the parent
        ReuseDistance.setcolor!(tree, n, ReuseDistance.Red)
        @test ReuseDistance.getcolor(tree, n) == ReuseDistance.Red
        @test ReuseDistance.getparent(tree, n) == 0
        @test ReuseDistance.leftchild(tree, n) == 0
        @test ReuseDistance.rightchild(tree, n) == 0

        # Similarly, setting the parent should not affect the color.
        ReuseDistance.setparent!(tree, n, typemax(Int64))
        @test ReuseDistance.getcolor(tree, n) == ReuseDistance.Red
        @test ReuseDistance.getparent(tree, n) == typemax(Int64)
        @test ReuseDistance.leftchild(tree, n) == 0
        @test ReuseDistance.rightchild(tree, n) == 0

        ReuseDistance.setleft!(tree, n, 10)
        ReuseDistance.setright!(tree, n, 33)
        @test ReuseDistance.getcolor(tree, n) == ReuseDistance.Red
        @test ReuseDistance.getparent(tree, n) == typemax(Int64)
        @test ReuseDistance.leftchild(tree, n) == 10
        @test ReuseDistance.rightchild(tree, n) == 33

        # Test misc accessors
        @test ReuseDistance.child_direction(tree, n, 10) == ReuseDistance.Left
        @test ReuseDistance.child_direction(tree, n, 33) == ReuseDistance.Right
        @test ReuseDistance.safeparent(tree, n) == typemax(Int64)
        @test ReuseDistance.safeparent(tree, 0) == 0
        m = tree[]
        @test m == 2
        ReuseDistance.setparent!(tree, n, 0)
        ReuseDistance.setparent!(tree, m, n)
        ReuseDistance.setleft!(tree, n, m)
        @test ReuseDistance.child_direction(tree, m) == ReuseDistance.Left

        ReuseDistance.setleft!(tree, n, 0)
        ReuseDistance.setright!(tree, n, m)
        @test ReuseDistance.child_direction(tree, m) == ReuseDistance.Right
        @test ReuseDistance.safeparent(tree, m) == n
        @test ReuseDistance.safegrandparent(tree, m) == 0
    end

    @testset "Testing Tree Operations" begin
        function clear!(tree, n)
            ReuseDistance.setcolor!(tree, n, ReuseDistance.Black)
            ReuseDistance.setparent!(tree, n, 0)
            ReuseDistance.setleft!(tree, n, 0)
            ReuseDistance.setright!(tree, n, 0)
            tree[n] = 0
            return n
        end

        # Now, we get a bit more elaborate with our tree setup, testing out tree rotations
        # and the accessors for uncles, nephews etc.
        #
        # Out tree will look like this.
        #
        #         A
        #        / \
        #       B   C
        #      / \   \
        #     D   E   F
        function setup_tree()
            tree = ReuseDistance.RedBlackTree{Int}(10)
            a = clear!(tree, tree[])
            b = clear!(tree, tree[])
            c = clear!(tree, tree[])
            d = clear!(tree, tree[])
            e = clear!(tree, tree[])
            f = clear!(tree, tree[])

            tree.root = 1
            ReuseDistance.setleft!(tree, a, b)
            ReuseDistance.setparent!(tree, b, a)

            ReuseDistance.setright!(tree, a, c)
            ReuseDistance.setparent!(tree, c, a)

            ReuseDistance.setright!(tree, c, f)
            ReuseDistance.setparent!(tree, f, c)

            ReuseDistance.setleft!(tree, b, d)
            ReuseDistance.setparent!(tree, d, b)
            ReuseDistance.setright!(tree, b, e)
            ReuseDistance.setparent!(tree, e, b)
            return tree, (; a, b, c, d, e, f)
        end

        tree, nodes = setup_tree()
        @test ReuseDistance.sibling(tree, nodes.b) == nodes.c
        @test ReuseDistance.sibling(tree, nodes.c) == nodes.b
        @test ReuseDistance.sibling(tree, nodes.f) == 0
        @test ReuseDistance.sibling(tree, nodes.d) == nodes.e
        @test ReuseDistance.sibling(tree, nodes.e) == nodes.d

        @test ReuseDistance.getuncle(tree, nodes.d) == nodes.c
        @test ReuseDistance.getuncle(tree, nodes.e) == nodes.c
        @test ReuseDistance.getuncle(tree, nodes.f) == nodes.b

        @test ReuseDistance.closenephew(tree, nodes.c) == nodes.e
        @test ReuseDistance.distantnephew(tree, nodes.c) == nodes.d

        @test ReuseDistance.closenephew(tree, nodes.b) == 0
        @test ReuseDistance.distantnephew(tree, nodes.b) == nodes.f

        #####
        ##### Tree Rotations
        #####

        # After a right rotation on A
        #
        #         B
        #        / \
        #       D   A
        #          / \
        #         E   C
        #              \
        #               F
        ReuseDistance.rotateright!(tree, nodes.a)
        @test tree.root == nodes.b
        @test ReuseDistance.getparent(tree, nodes.b) == 0

        @test ReuseDistance.leftchild(tree, nodes.b) == nodes.d
        @test ReuseDistance.getparent(tree, nodes.d) == nodes.b
        @test ReuseDistance.rightchild(tree, nodes.b) == nodes.a
        @test ReuseDistance.getparent(tree, nodes.a) == nodes.b

        @test ReuseDistance.leftchild(tree, nodes.a) == nodes.e
        @test ReuseDistance.getparent(tree, nodes.e) == nodes.a

        @test ReuseDistance.rightchild(tree, nodes.a) == nodes.c
        @test ReuseDistance.getparent(tree, nodes.c) == nodes.a

        # After a left rotation on A
        #           C
        #          / \
        #         A   F
        #        /
        #       B
        #      / \
        #     D   E
        tree, nodes = setup_tree()
        ReuseDistance.rotateleft!(tree, nodes.a)
        @test tree.root == nodes.c
        @test ReuseDistance.getparent(tree, nodes.c) == 0
        @test ReuseDistance.rightchild(tree, nodes.c) == nodes.f
        @test ReuseDistance.getparent(tree, nodes.f) == nodes.c

        @test ReuseDistance.leftchild(tree, nodes.c) == nodes.a
        @test ReuseDistance.getparent(tree, nodes.a) == nodes.c

        @test ReuseDistance.rightchild(tree, nodes.a) == 0
        @test ReuseDistance.leftchild(tree, nodes.a) == nodes.b
        @test ReuseDistance.getparent(tree, nodes.b) == nodes.a

        # Finally, perform a rotation that doesn't change the root
        # Right rotation on `B`.
        #
        #
        #         A
        #        / \
        #       D   C
        #        \   \
        #         B   F
        #          \
        #           E
        tree, nodes = setup_tree()
        ReuseDistance.rotateright!(tree, nodes.b)
        @test tree.root == nodes.a
        @test ReuseDistance.leftchild(tree, nodes.a) == nodes.d
        @test ReuseDistance.getparent(tree, nodes.d) == nodes.a
        @test ReuseDistance.leftchild(tree, nodes.d) == 0
        @test ReuseDistance.rightchild(tree, nodes.d) == nodes.b
        @test ReuseDistance.getparent(tree, nodes.b) == nodes.d

        #####
        ##### Search
        #####

        tree, nodes = setup_tree()
        tree[nodes.a] = 20
        tree[nodes.b] = 10
        tree[nodes.c] = 30
        tree[nodes.d] = 5
        tree[nodes.e] = 15
        tree[nodes.f] = 35

        @test ReuseDistance.search(tree, 20) == (nodes.a, ReuseDistance.Found)
        @test ReuseDistance.search(tree, 10) == (nodes.b, ReuseDistance.Found)
        @test ReuseDistance.search(tree, 30) == (nodes.c, ReuseDistance.Found)
        @test ReuseDistance.search(tree, 5) == (nodes.d, ReuseDistance.Found)
        @test ReuseDistance.search(tree, 15) == (nodes.e, ReuseDistance.Found)
        @test ReuseDistance.search(tree, 35) == (nodes.f, ReuseDistance.Found)

        # Look for findings
        @test ReuseDistance.search(tree, 25) == (nodes.c, ReuseDistance.NotFoundLeft)
        @test ReuseDistance.search(tree, 16) == (nodes.e, ReuseDistance.NotFoundRight)
    end

    #####
    ##### Insertion!
    #####

    @testset "Testing Insertion" begin
        tree = ReuseDistance.RedBlackTree{Int}()
        for i in 1:100
            push!(tree, i)
        end

        @test ReuseDistance.validate(tree)
        @test length(tree) == 100
        @test all(in(tree), 1:100)
        @test !any(in(tree), 101:200)
    end

    #####
    ##### Stress Testing
    #####

    @testset "Performing Stress Test" begin
        groundtruth = Set{Int}()
        tree = ReuseDistance.RedBlackTree{Int}()
        domain = 1:10000
        numswaps = 1000
        increment = 0.02

        swapcount = 0
        add = true
        meter = ProgressMeter.Progress(numswaps, 1)
        while swapcount <= numswaps
            swapchance = 0.0
            while rand() > swapchance
                numops = rand(1:10)
                for _ in Base.OneTo(numops)
                    if add
                        i = rand(domain)
                        while length(groundtruth) < length(domain) && in(i, groundtruth)
                            i = rand(domain)
                        end
                        push!(tree, i)
                        push!(groundtruth, i)
                    elseif !isempty(groundtruth)
                        i = rand(groundtruth)
                        delete!(tree, i)
                        delete!(groundtruth, i)
                    end
                end
                swapchance += increment
            end

            passed = true
            for i in domain
                if in(i, groundtruth)
                    passed &= in(i, tree)
                else
                    passed &= !in(i, tree)
                end
            end

            @test passed
            @test ReuseDistance.validate(tree)
            swapcount += 1
            add = !add
            ProgressMeter.next!(meter)
        end
    end
end
