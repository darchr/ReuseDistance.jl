@testset "Testing RedBlack Tree" begin
    @test reverse(ReuseDistance.Left) == ReuseDistance.Right
    @test reverse(ReuseDistance.Right) == ReuseDistance.Left

    @testset "Testing Accessors" begin
    end
end
