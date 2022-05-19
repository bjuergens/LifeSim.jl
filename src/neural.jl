
if abspath(PROGRAM_FILE) == @__FILE__
    # include("lin.jl") 
    # include("models.jl") 
end

module LSNaturalNet
export NaturalNet, genome_size, step!, init_random_network
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
        , 0.01
        )
    NaturalNet(genome::SVector;input_dim=2, neural_dim=2, output_dim=2, delta_t=0.01) = new{input_dim,neural_dim,output_dim,Float32}(
        Ref(SVector{neural_dim,Float32}(zeros(neural_dim)))
        , SMatrix( reshape(genome[1:input_dim*neural_dim]                                                                     , Size(input_dim,neural_dim)))
        , SMatrix( reshape(genome[input_dim*neural_dim+1:input_dim*neural_dim+neural_dim^2]                                   , Size(neural_dim,neural_dim)))
        , SMatrix( reshape(genome[input_dim*neural_dim+neural_dim^2+1:input_dim*neural_dim+neural_dim^2+neural_dim*output_dim], Size(neural_dim,output_dim)))
        , @SVector zeros(genome_size(input_dim,neural_dim,output_dim))
        , delta_t
        )
end #struct

function genome_size(dim_in::Int,dim_N::Int,dim_out::Int)
    return dim_in*dim_N + dim_N*dim_N + dim_N*dim_out
end

function init_random_network(dim_in, dim_N, dim_out)
    rand_genome_size = genome_size(dim_in,dim_N,dim_out)
    rand_genome2 = randn((SVector){rand_genome_size, Float32})
    return NaturalNet(rand_genome2, input_dim=dim_in, neural_dim=dim_N, output_dim=dim_out)
end

"do a single step in a natural net. Update the internal state. 
@returns output of the network"
function step!(ctrnn::NaturalNet, input::SVector)
    input_with_V = tanh.(input)' * ctrnn.V
    dydt = (ctrnn.neural_state[]' * ctrnn.W) + ( input_with_V )
    ctrnn.neural_state[] = ctrnn.neural_state[]' + ctrnn.delta_t * dydt
    output = max.(0, ctrnn.neural_state[]' * ctrnn.T)
    return output
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

    # type within the network should be consistent
    net_dim_in, net_dim_N, net_dim_out, net_precision = typeof(test_net2).parameters
    ns_data, ns_prec, ns_dim1, ns_dim2 = typeof(test_net2.neural_state[]).parameters
    @test ns_dim2 == net_dim_N
    @test ns_prec == net_precision

    # an update step produces non-zero output and updates the neural state
    test_input = SVector{2,Float32}(1:2)
    old_state = deepcopy( test_net2.neural_state[])
    @test old_state == test_net2.neural_state[]
    output = step!(test_net2, test_input)
    @test old_state != test_net2.neural_state[]
    @test all(output .!= zeros(4,1))
    @test ndims(output) == ndims(zeros(4,1))

    # generate some random brains
    for i in 1:10
        rand_net =  init_random_network(5,11,7)
        rand_old_state = deepcopy( rand_net.neural_state[])
        rand_input = randn((SVector){5, Float32})
        @test rand_old_state == rand_net.neural_state[]
        rand_output = step!(rand_net, rand_input)
        @test rand_old_state != rand_net.neural_state[]
    end

end
end
end #module NaturalNetTests

if abspath(PROGRAM_FILE) == @__FILE__
    using .NaturalNetTests
    doTest()
end

