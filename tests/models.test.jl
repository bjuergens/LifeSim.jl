
if abspath(PROGRAM_FILE) == @__FILE__
    include("../src/models.jl")
end

using Test
using SafeTestsets


@safetestset "Examples" begin

    using ..MyModels
    using ..MyModelExamples
    
    @test 0<aAgent.pos.x<1
    @test 1+1==2 
end


