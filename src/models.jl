
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
    Agent(idx; pos=Vec2(0.3, 0.3), direction_angle=0.0, speed=0.1, size=0.05, color=255) = new(pos,direction_angle,speed,size,color,idx)
end

"current step of sim"
struct SimulationStep
    num_step::Int
    agent_list::Vector{Agent}
    next_agent_id::Int
    last_frame_time_ms::Float64
    step_of_last_cull::Int
    SimulationStep(;num_step=1, agent_list=[], next_agent_id=1, last_frame_time_ms=50.0, step_of_last_cull=1) = 
        new(num_step,agent_list,next_agent_id,last_frame_time_ms,step_of_last_cull)
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
export simState, aAgent, bAgent, stepStep
using ..LSModels
using CImGui: IM_COL32
# aAgent = Agent(1, pos=Vec2(0.3, 0.3), direction_angle= pi/2, speed=0.01, size=0.11, color=IM_COL32(11,11,0,255),1)
aAgent = Agent(1)
bAgent = Agent(2, pos=Vec2(0.6, 0.6), direction_angle=2*pi,  speed=0.02, size=0.13, color=IM_COL32(22,22,0,255))   
# stepStep = SimulationStep(agent_list= [aAgent, bAgent])
simState = SimulationState(SimulationStep(agent_list= [aAgent, bAgent]))
end #module MyModelExamples


module ModelTests
export doTest
using Test
using ..LSModels

using ..LSModelExamples
function doTest()
@testset "Examples" begin
    @info "ModelExamples" aAgent bAgent simState

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
