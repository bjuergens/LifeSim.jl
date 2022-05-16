
if abspath(PROGRAM_FILE) == @__FILE__
    # include("lin.jl") 
    # include("models.jl") 
end

module LSNaturalNet
export NaturalNet
using StaticArrays

mutable struct NaturalNet
    input_dim::Int
    output_dim::Int
    neural_state::SVector

    NaturalNet(;input_dim=3, neural_dim=5, output_dim=4) = new(
        input_dim,
        output_dim,
        @SVector zeros(neural_dim)
        )
end

end #module


module NaturalNetTests
export doTest
using Test
using ..LSNaturalNet
function doTest()
@testset "NaturalNetTest" begin
    @show NaturalNet()
    @test 1+1==2  # canary
    @test NaturalNet().input_dim > 0
    @test NaturalNet().output_dim > 0
end
end
end #module NaturalNetTests

if abspath(PROGRAM_FILE) == @__FILE__
    using .NaturalNetTests
    doTest()
end
