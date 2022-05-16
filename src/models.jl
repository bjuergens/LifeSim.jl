
if abspath(PROGRAM_FILE) == @__FILE__
    include("lin.jl") 
end

module LSModels
export Agent, SensorData
export SimulationState, ControlState, SimulationStep, Vec2

using CImGui: IM_COL32
using ..LSLin

"a single individual in sim"
mutable struct Agent
    pos::Vec2
    direction_angle:: Cfloat
    speed::Cfloat
    size::Cfloat
    color::UInt32
    id::Int
end

"current step of sim"
struct SimulationStep
    num_step::Int
    agent_list::Vector{Agent}
    last_frame_time_ms::Float64
end

"info sent from sim to gui"
mutable struct SimulationState
    last_step::Ref{SimulationStep}
end

"info sent from gui to sim"
mutable struct ControlState
    is_stop::Bool
    min_frametime_ms::Cfloat
    cull_minimum::Cint
    cull_frequency::Cfloat
    cull_percentage::Cfloat
    request_revise::Int
    request_pause::Int
    request_play::Int
    request_add_agent::Int

    ControlState(; is_stop=false, min_frame_time=100, cull_minimum=5, cull_frequency=100, cull_percentage=0.3, 
            request_revise=1,request_pause=1, request_play=1,request_add_agent=1) =
        new(       is_stop,        min_frame_time,    cull_minimum,   cull_frequency,     cull_percentage,
            request_revise,  request_pause,   request_play,  request_add_agent)
    # ControlState() = new(Cfloat[sin(x) for x in 0:0.05:2pi], false, 1.0, 50.0, 2, 2, 2, 2)
end

end #module LSModels


"""viable example for all models used by testclasses for most other modules in this repo"""
module LSModelExamples
export simState, aAgent, bAgent, stepStep, ccc
using ..LSModels
using CImGui: IM_COL32
aAgent = Agent(Vec2(0.3, 0.3), pi/2, 0.01, 0.11, IM_COL32(11,11,0,255),1)
bAgent = Agent(Vec2(0.6, 0.6), 2*pi, 0.02, 0.13, IM_COL32(22,22,0,255),2)   
stepStep = SimulationStep(1, [aAgent, bAgent], 0.1)
simState = SimulationState(stepStep)
ccc = ControlState()
end #module MyModelExamples


module ModelTests
export doTest
using Test
using ..LSModels

using ..LSModelExamples
function doTest()
@testset "Examples" begin
    @info "ModelExamples" aAgent bAgent simState stepStep

    @test 0<aAgent.pos.x<1
    @test !ControlState().is_stop
    @test 1+1==2  # canary
end
end
end #module ModelTests

if abspath(PROGRAM_FILE) == @__FILE__
    using .ModelTests
    doTest()
end
