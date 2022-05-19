
if abspath(PROGRAM_FILE) == @__FILE__
    # include("lin.jl") 
    # include("models.jl") 
end

module LSNaturalNet
export NaturalNet, genome_size, step!
using StaticArrays
# using LinearAlgebra

struct NaturalNet{dim_in,dim_N,dim_out,precision<:AbstractFloat}
    neural_state::Ref{SVector{dim_N, precision}}
    V::SMatrix{dim_in, dim_N  , precision}
    W::SMatrix{dim_N , dim_N  , precision}
    T::SMatrix{dim_N , dim_out, precision}
    genome::SVector
    delta_t::precision

    "create dummy object with zero values"
    NaturalNet(;input_dim=2, neural_dim=4, output_dim=3) = new{input_dim,neural_dim,output_dim,Float32}(
        Ref(SVector{neural_dim,Float32}(zeros(neural_dim)))
        , @SMatrix zeros(input_dim,neural_dim)
        , @SMatrix zeros(neural_dim,neural_dim)
        , @SMatrix zeros(neural_dim,output_dim)
        , @SVector zeros(genome_size(input_dim,neural_dim,output_dim))
        , 0.1
        )
    NaturalNet(genome::SVector;input_dim=2, neural_dim=2, output_dim=2, delta_t=0.1) = new{input_dim,neural_dim,output_dim,Float32}(
        Ref(SVector{neural_dim,Float32}(zeros(neural_dim)))
        , SMatrix( reshape(genome[1:input_dim*neural_dim]                                                                     , Size(input_dim,neural_dim)))
        , SMatrix( reshape(genome[input_dim*neural_dim+1:input_dim*neural_dim+neural_dim^2]                                   , Size(neural_dim,neural_dim)))
        , SMatrix( reshape(genome[input_dim*neural_dim+neural_dim^2+1:input_dim*neural_dim+neural_dim^2+neural_dim*output_dim], Size(neural_dim,output_dim)))
        , @SVector zeros(genome_size(input_dim,neural_dim,output_dim))
        , delta_t
        )
end #struct

# todo: get genome size from type
function genome_size(dim_in::Int,dim_N::Int,dim_out::Int)
    return dim_in*dim_N + dim_N*dim_N + dim_N*dim_out
end

function step!(ctrnn::NaturalNet, input::SVector)

    net_dim_in,net_dim_N,net_dim_out,net_precision = typeof(ctrnn).parameters
    ns_data, ns_prec, ns_dim1, ns_dim2 = typeof(ctrnn.neural_state[]).parameters
    @assert ns_dim2 == net_dim_N
    @assert ns_prec == net_precision
    input_after_actiation = tanh.(input)
    dydt = (ctrnn.neural_state[]' * ctrnn.W) + ( input_after_actiation' * ctrnn.V )
    ctrnn.neural_state[] = ctrnn.neural_state[]' + ctrnn.delta_t * dydt
    out = ctrnn.neural_state[]' * ctrnn.T

    out_after_relu = max.(0, out)
    return out_after_relu
end

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

    @test genome_size(2,2,2) == 4+4+4
    @test genome_size(3,2,2) == 6+4+4
    @test genome_size(2,2,3) == 4+4+6
    @test genome_size(2,3,2) == 6+9+6

    test_genome_size = genome_size(2,3,4)
    test_genome = SVector{test_genome_size,Float32}( 1:test_genome_size)
    test_net2 =  NaturalNet(test_genome, input_dim=2, neural_dim=3, output_dim=4)
    @test test_net2.V == reshape( 1:6  , (2,3))    
    @test test_net2.W == reshape( 7:15 , (3,3))    
    @test test_net2.T == reshape( 16:27, (3,4))
    @test 1+1==2  # canary

    # an update step produces non-zero output and updates the neural state
    test_input = SVector{2,Float32}(1:2)
    old_state = deepcopy( test_net2.neural_state[])
    @test old_state == test_net2.neural_state[]
    output = step!(test_net2, test_input)
    @test old_state != test_net2.neural_state[]
    @test all(output .!= zeros(4,1))
    @test ndims(output) == ndims(zeros(4,1))
end
end
end #module NaturalNetTests

if abspath(PROGRAM_FILE) == @__FILE__
    using .NaturalNetTests
    doTest()
end
