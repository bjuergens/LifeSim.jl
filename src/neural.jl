
if abspath(PROGRAM_FILE) == @__FILE__
    # include("lin.jl") 
    # include("models.jl") 
end

module LSNaturalNet
export NaturalNet
using StaticArrays
# using LinearAlgebra

struct NaturalNet{dim_in,dim_N,dim_out,precision<:AbstractFloat}
    neural_state::Ref{SVector{dim_N, precision}}
    V::SMatrix{dim_in, dim_N  , precision}
    W::SMatrix{dim_N , dim_N  , precision}
    T::SMatrix{dim_N , dim_out, precision}

    "create dummy object with zero values"
    NaturalNet(;input_dim=2, neural_dim=4, output_dim=3) = new{input_dim,neural_dim,output_dim,Float32}(
        Ref(SVector{neural_dim,Float32}(zeros(neural_dim)))
        , @SMatrix zeros(input_dim,neural_dim)
        , @SMatrix zeros(neural_dim,neural_dim)
        , @SMatrix zeros(neural_dim,output_dim)
        )
end #struct

end #module


module NaturalNetTests
export doTest
using Test
using ..LSNaturalNet
# using LinearAlgebra
using StaticArrays
function doTest()
@testset "NaturalNetTest" begin

    vec3d = SA_F32[1, 2, 3 ] 
    mat2d = SA_F32[1 2; 3 4] 
    @test mat2d isa SMatrix{2,2,Float32}
    @test vec3d isa SVector{3,Float32}

    @test length(NaturalNet().V) >  0
    @test length(NaturalNet().W) >  0
    @test length(NaturalNet().T) >  0

    # matrices are immuatble
    @test_throws ErrorException NaturalNet().V[1]=2 
    @test_throws ErrorException NaturalNet().W[1]=2 
    @test_throws ErrorException NaturalNet().T[1]=2 

    # neural state can be updated
    test_net =  NaturalNet()
    @test test_net.neural_state[][1] == 0
    test_net.neural_state[] = SVector{4,Float32}(ones(4))
    @test test_net.neural_state[][1] == 1
    
    @test 1+1==2  # canary
end
end
end #module NaturalNetTests

if abspath(PROGRAM_FILE) == @__FILE__
    using .NaturalNetTests
    doTest()
end
