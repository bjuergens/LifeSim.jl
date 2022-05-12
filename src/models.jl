
module MyModels
    export Agent, makeAgent
    export SimulationState, ControlState, SimulationStep, Vec2

    using CImGui: IM_COL32

    "position in simulation-space"
    Vec2 = @NamedTuple{x::Cfloat,y::Cfloat}

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
        request_simulation_state_at_age::Int
    end
end

"""viable example for all models"""
module MyModelExamples
    export ctrlState, simState, aAgent, bAgent, stepStep
    using ..MyModels
    using CImGui: IM_COL32
    aAgent = Agent((x=0.3, y=0.3), pi/2, 0.01, 0.11, IM_COL32(11,11,0,255),1)
    bAgent = Agent((x=0.6, y=0.6), 2*pi, 0.02, 0.13, IM_COL32(22,22,0,255),2)   
    ctrlState = ControlState(Cfloat[sin(x) for x in 0:0.05:2pi], false,0.9, 50.0, 5)
    stepStep = SimulationStep(1, [aAgent, bAgent], 0.1)
    simState = SimulationState(stepStep)
end


    
if abspath(PROGRAM_FILE) == @__FILE__
    using ..MyModelExamples
    @info "ModelExamples" aAgent bAgent ctrlState simState stepStep
    include("../tests/models.test.jl")
end