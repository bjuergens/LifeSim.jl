
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
using Distributions: Normal # too slow!!


function myrand()
    return rand()^2
end
function randdiff(input)
    # return input * (1.1 - rand()^2 )
    return rand(Normal(input, 0.1), 1)[1]
end

    # todo: extra module for evo-stuff
    function mutate(aAgent::Agent, next_agent_id)
        
        parent_genome = aAgent.brain.genome
        @show parent_genome
        # rand(Normal(input, 0.1), 1)

        return Agent(next_agent_id,
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

using Test

function doTest()

@testset "LSEvolutionTesT" begin
    @test 1+1≈2 #canary
end


end

end #module LSEvolutionTest



if abspath(PROGRAM_FILE) == @__FILE__
    using .LSEvolutionTest
    doTest()
end
