
if abspath(PROGRAM_FILE) == @__FILE__
    include("lin.jl") 
    include("neural.jl") 
    include("models.jl") 
end

module LSEvolution
export mutate_duo, split_color, crossover_duo
using ..LSNaturalNet
using ..LSLin
using ..LSModels
using Distributions: Normal
using CImGui: IM_COL32
using StaticArrays

    function randdiff(input, σ)
        return rand(Normal(input, σ), 1)[1]
    end

    function mutate_genome_duo(parent_genome, mutation_rate)
        perturb = rand(Normal(0,mutation_rate), length(parent_genome))
        result1 = wrap.(parent_genome + perturb, -10, 20)
        result2 = wrap.(parent_genome - perturb, -10, 20)
        return result1, result2
    end

    function crossover_genome(parent1, parent2)
        @assert length(parent1) == length(parent2) 

        len::Int = length(parent1) - 1
        split1::Int = floor(2+ rand() * len)
        split2::Int = floor(2+ rand() * len)
        if split1 > split2
            split1, split2 = split2, split1
        end
        if split1==split2
            split1 = 1
        end
        child1 = vcat( parent1[1:split1], parent2[split1+1:split2], parent1[split2+1:end] )
        child2 = vcat( parent2[1:split1], parent1[split1+1:split2], parent2[split2+1:end] )
        

        return SVector{length(child1),Float32}(child1), SVector{length(child2),Float32}(child2)
    end

    function make_child_from_genome(child_genome, direction, child_mut_rate, parent::Agent, next_agent_id::Int)

        net_dim_in, net_dim_N, net_dim_out, net_precision = typeof(parent.brain).parameters
        child_brain = NaturalNet(child_genome, input_dim=net_dim_in, neural_dim=net_dim_N, output_dim=net_dim_out)
        # todo: children are smaller at birth and grow overtime
        child_size = parent.size 
        child_speed = 0
        child_pos = move_in_direction( parent.pos, direction, child_size + parent.size )
        p_r, p_g, p_b, p_a = split_color(parent.color)
        c_r = wrap(p_r+5,0, 255)
        c_g = wrap(floor(randdiff(p_g,1)),0, 255)
        c_b = p_b
        child_color = IM_COL32(c_r,c_g,c_b,255)

        return Agent(next_agent_id, child_brain,
                        pos=child_pos,
                        direction_angle=direction,
                        size=child_size, 
                        speed=child_speed, 
                        color=child_color,
                        mutation_rate=child_mut_rate) 
    end

    function crossover_duo(p1::Agent, p2::Agent, next_agent_id::Int)
        child_genome1, child_genome2 = crossover_genome(p1.brain.genome, p1.brain.genome)
        result1 = make_child_from_genome(child_genome1, p1.direction_angle + pi/4, p1.mutation_rate, p1, next_agent_id)
        result2 = make_child_from_genome(child_genome2, p2.direction_angle - pi/4, p2.mutation_rate, p2, next_agent_id+1)

        return result1, result2
    end

    function mutate_duo(parent::Agent, next_agent_id)
        child_mut_rate = clamp( randdiff(parent.mutation_rate, 0.001), 0.00001, 0.1)
        child_genome1, child_genome2 = mutate_genome_duo(parent.brain.genome, child_mut_rate)
        child1 =  make_child_from_genome(child_genome1, parent.direction_angle + pi/2, child_mut_rate, parent, next_agent_id)
        child2 =  make_child_from_genome(child_genome2, parent.direction_angle - pi/2, child_mut_rate, parent, next_agent_id+1)
        return child1, child2
    end


end #module LSEvolution


module LSEvolutionTests
export doTest
using ..LSEvolution
using ..LSModelExamples
using ..LSEvolution
using ..LSModels
using ..LSNaturalNet
using Test
using Flatten
using StaticArrays

function doTest()

@testset "LSEvolutionTests" begin
    @test 1+1≈2 #canary

    aAgent = Agent(1, init_random_network(2, 3, 4), pos=Vec2(0.1,0.1))  
    @inferred mutate_duo(aAgent,1)
    @inferred LSEvolution.randdiff(123, 0.01)

    brain = init_random_network(num_sensors, 10, num_intentions)
    parent = Agent(1, brain, pos=Vec2(0.3,0.3), direction_angle=0, speed=0.02, size=0.05, color=0xff224466)   

    child1, child2 = mutate_duo(parent,3)
    
    @test !(child1.pos ≈ parent.pos)
    @test !(child1.color ≈ parent.color)
    @test length(child1.brain.neural_state[]) == length(parent.brain.neural_state[])
    @test length(child1.brain.V) == length(parent.brain.V)
    @test !(child1.pos ≈ child2.pos)
    @test length(child1.brain.neural_state[]) == length(child2.brain.neural_state[])
    @test length(child1.brain.V) == length(child2.brain.V)
    # @show child1.brain.genome child2.brain.genome
    @test !all(isapprox.(child1.brain.genome, child2.brain.genome))
    
    # todo: move this to convert method
    some_input = SensorInput(1,2,3,Vec2(4,5))
    input_data = flatten(some_input)
    input_vector =  SVector{length(input_data),Float32}(input_data)

    parent_desire = step!(parent.brain, input_vector)
    child_desire = step!(child1.brain, input_vector)

    @test length(parent_desire) == length(child_desire)
    @test length(child1.brain.neural_state[]) == length(parent.brain.neural_state[])
    @test length(child1.brain.V) == length(parent.brain.V)

    @inferred Tuple{SVector,SVector} LSEvolution.crossover_genome(collect(1:5),collect(-1:-1:-5))

    parent1, parent2 = collect(1:25), collect(-1:-1:-25)
    child1, child2 = LSEvolution.crossover_genome(parent1, parent2)
    @test all(map(x-> x==0, child1 .+ child2 )) # children are exact opposites, because parents were. 
    @test length(child1) == length(child2) == length(parent1) == length(parent2)
    @test_throws AssertionError LSEvolution.crossover_genome(collect(1:26), collect(-1:-1:-25))
    @test_throws AssertionError LSEvolution.crossover_genome(collect(1:24), collect(-1:-1:-25))
    
    brain1 = init_random_network(2,3,4)
    brain2 = init_random_network(2,3,4)

    cc1, cc2 = crossover_duo(Agent(3,brain1), Agent(4,brain2),5)

    # gene in child must come from one of the parents
    @test cc1.brain.genome[1] == brain1.genome[1] || cc1.brain.genome[1] == brain2.genome[1]
    @test cc2.brain.genome[1] == brain1.genome[1] || cc2.brain.genome[1] == brain2.genome[1]
end


end

end #module LSEvolutionTests



if abspath(PROGRAM_FILE) == @__FILE__
    using .LSEvolutionTests
    doTest()
end
