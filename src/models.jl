
if abspath(PROGRAM_FILE) == @__FILE__
    include("lin.jl") 
end

module LSModels
export Agent, SensorData
export SimulationState, ControlState, SimulationStep, Vec2

using CImGui: IM_COL32
using ..LSLin

"position in simulation-space"


mutable struct Agent
    pos::Vec2
    direction_angle:: Cfloat
    speed::Cfloat
    size::Cfloat
    color::UInt32
    id::Int
end

struct SimulationStep
    num_step::Int
    agent_list::Vector{Agent}
    last_frame_time_ms::Float64
end

mutable struct SimulationState
    last_step::Ref{SimulationStep}
end

mutable struct ControlState
    arr::Vector{Cfloat}
    is_stop::Bool
    afloat::Cfloat
    min_frametime_ms::Cfloat
    request_revise::Int
end
end #module LSModels


"""viable example for all models used by testclasses for most other modules in this repo"""
module LSModelExamples
export ctrlState, simState, aAgent, bAgent, stepStep
using ..LSModels
using CImGui: IM_COL32
aAgent = Agent(Vec2(0.3, 0.3), pi/2, 0.01, 0.11, IM_COL32(11,11,0,255),1)
bAgent = Agent(Vec2(0.6, 0.6), 2*pi, 0.02, 0.13, IM_COL32(22,22,0,255),2)   
ctrlState = ControlState(Cfloat[sin(x) for x in 0:0.05:2pi], false,0.9, 50.0, 5)
stepStep = SimulationStep(1, [aAgent, bAgent], 0.1)
simState = SimulationState(stepStep)
end #module MyModelExamples


module ModelTests
# Testing-module is needed as workaround for error "ERROR: LoadError: UndefVarError: @safetestset not defined"
# when macro is called in toplevel-block that is not a module.
using SafeTestsets
export doTest
function doTest()
@safetestset "Examples" begin
    using ...LSModels
    using ...LSModelExamples
    @info "ModelExamples" aAgent bAgent ctrlState simState stepStep

    @test 0<aAgent.pos.x<1
    @test 1+1==2  # canary
end
end
end #module ModelTests

if abspath(PROGRAM_FILE) == @__FILE__
    using .ModelTests
    doTest()
end
