
if abspath(PROGRAM_FILE) == @__FILE__
    include("lin.jl") 
    include("neural.jl") 
    include("models.jl") 
end

module LSEvolution
export mutate
using ..LSNaturalNet
using ..LSLin
using ..LSModels
using Distributions: Normal


function randdiff(input)
    return rand(Normal(input, 0.1), 1)[1]
end

    function mutate(aAgent::Agent, next_agent_id, σ=0.01)
        net_dim_in, net_dim_N, net_dim_out, net_precision = typeof(aAgent.brain).parameters
        parent_genome = aAgent.brain.genome
        pertube = rand(Normal(0,σ), length(parent_genome))
        child_genome = pertube + parent_genome
        child_brain = NaturalNet(child_genome, input_dim=net_dim_in, neural_dim=net_dim_N, output_dim=net_dim_out, delta_t=0.01)
        return Agent(next_agent_id, child_brain,
                        pos=Vec2(randdiff(aAgent.pos.x), randdiff(aAgent.pos.y)),
                        direction_angle=randdiff(aAgent.direction_angle), 
                        size=clip(randdiff(aAgent.size),0.01,0.05), 
                        speed=randdiff(aAgent.speed), 
                        color=abs(floor(randdiff(aAgent.color))))
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
