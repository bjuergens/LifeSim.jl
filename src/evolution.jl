
if abspath(PROGRAM_FILE) == @__FILE__
    include("lin.jl") 
    include("neural.jl") 
    include("models.jl") 
end

module LSEvolution
export mutate, split_color
using ..LSNaturalNet
using ..LSLin
using ..LSModels
using Distributions: Normal
using CImGui: IM_COL32

    function randdiff(input)
        return rand(Normal(input, 0.1), 1)[1]
    end

    function mutate(parent::Agent, next_agent_id, σ=0.01)
        net_dim_in, net_dim_N, net_dim_out, net_precision = typeof(parent.brain).parameters
        parent_genome = parent.brain.genome
        pertube = rand(Normal(0,σ), length(parent_genome))
        child_genome = pertube + parent_genome
        child_brain = NaturalNet(child_genome, input_dim=net_dim_in, neural_dim=net_dim_N, output_dim=net_dim_out, delta_t=0.01)
        # todo: children are smaller at birth and grow overtime
        child_size = parent.size 
        child_direction = -parent.direction_angle
        # todo: children start with 0 speed and it changes via actions
        child_speed = randdiff(parent.speed) 
        child_pos = move_in_direction( parent.pos, -parent.direction_angle, child_size + parent.size )
        p_r, p_g, p_b, p_a = split_color(parent.color)
        c_r = wrap(p_r+11,0, 255)
        c_g = wrap(floor(randdiff(p_g)),0, 255)
        c_b = p_b
        child_color = IM_COL32(c_r,c_g,c_b,255)

        return Agent(next_agent_id, child_brain,
                        pos=child_pos,
                        direction_angle=child_direction, 
                        size=child_size, 
                        speed=child_speed, 
                        color=child_color)
    end


end #module LSEvolution


module LSEvolutionTest
export doTest
using ..LSEvolution
using ..LSModelExamples
using Test

function doTest()

@testset "LSEvolutionTesT" begin
    @test 1+1≈2 #canary

    @inferred mutate(aAgent,1)
    @inferred LSEvolution.randdiff(123)

    parent = aAgent
    child = mutate(parent,3)
    
    @test !(child.pos ≈ parent.pos)
    @test !(child.color ≈ parent.color)
end


end

end #module LSEvolutionTest



if abspath(PROGRAM_FILE) == @__FILE__
    using .LSEvolutionTest
    doTest()
end
