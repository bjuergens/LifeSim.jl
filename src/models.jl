
if abspath(PROGRAM_FILE) == @__FILE__
    include("lin.jl") 
    include("neural.jl") 
end

module LSModels

export Agent, SensorData, split_color
export SimulationState, ControlState, SimulationStep, Vec2

export SensorInput, Desire, num_sensors, num_intentions # use to init brains for initial population


using CImGui: IM_COL32
using StaticArrays
using ..LSLin
using ..LSNaturalNet

"helper that separates CImGui-Color into its components"
function split_color(color::UInt32)
    red   = color & 0x000000ff
    green = (color & 0x0000ff00) >> 8
    blue  = (color & 0x00ff0000) >> 16
    alpha = (color & 0xff000000) >> 24
    return red, green, blue, alpha
end


struct SensorInput
    compass_north::Cfloat ## direction to y-axis with respect to current direction
    compass_center::Cfloat ## direction to world middle with respect to current direction
    speed::Cfloat
    pos::Vec2
end

struct Desire
    rotate::Cfloat ## relative desired rotation, in [-1,1]
    accelerate::Cfloat ## change speed [-1,1]
end
# todo generate from struct
num_sensors = 5 
num_intentions = 2



"a single individual in sim"
mutable struct Agent
    id::Int64
    brain::NaturalNet
    pos::Vec2
    direction_angle:: Cfloat
    speed::Cfloat
    size::Cfloat
    color::UInt32
    Agent(idx, brain; pos=Vec2(0.3, 0.3), direction_angle=0.0, speed=0.1, size=0.1, color=0xff112233) = 
      new(idx, brain, pos,                direction_angle,     speed,     size,      color)
end

"current step of sim"
struct SimulationStep
    num_step::Int64
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
    cull_ratio::Cfloat
    request_revise::Int
    request_pause::Int
    request_play::Int
    request_add_agent::Int

    ControlState(; is_stop=false, min_frame_time=100, cull_minimum=20, cull_frequency=100, cull_ratio=0.3, 
            request_revise=1,request_pause=1, request_play=1,request_add_agent=1) =
        new(       is_stop,        min_frame_time,    cull_minimum,   cull_frequency,     cull_ratio,
            request_revise,  request_pause,   request_play,  request_add_agent)
    # ControlState() = new(Cfloat[sin(x) for x in 0:0.05:2pi], false, 1.0, 50.0, 2, 2, 2, 2)
end

end #module LSModels


"""viable example for all models used by testclasses for most other modules in this repo"""
module LSModelExamples
export simState, aAgent, bAgent, stepStep
using ..LSModels
using ..LSNaturalNet
using CImGui: IM_COL32
# aAgent = Agent(1, pos=Vec2(0.3, 0.3), direction_angle= pi/2, speed=0.01, size=0.11, color=IM_COL32(11,11,0,255),1)
# stepStep = SimulationStep(agent_list= [aAgent, bAgent])
simState = SimulationState(SimulationStep(agent_list= []))
end #module MyModelExamples


module ModelTests
export doTest
using Test
using Flatten
using CImGui: IM_COL32
using ..LSModels
using ..LSModelExamples
using StaticArrays


function doTest()
@testset "Examples" begin
    # @info "ModelExamples" aAgent bAgent simState

    @test !ControlState().is_stop
    @test 1+1==2  # canary

    (r,g,b,a) = split_color(IM_COL32(1,2,3,4))
    @test r == 1
    @test g == 2
    @test b == 3
    @test a == 4

    # WIP
    some_input = SensorInput(1,2,3,Vec2(4,5))
    #after_convert = convert(SVector, some_input)
    #@test after_convert == (1,2,3,4,5)

end
end
end #module ModelTests

if abspath(PROGRAM_FILE) == @__FILE__
    using .ModelTests
    doTest()
end
