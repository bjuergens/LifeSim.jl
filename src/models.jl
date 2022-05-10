
module MyModels
    export Agent
    export SimulationState, ControlState, SimulationStep

    mutable struct Agent
        pos_x::Cfloat
        pos_y::Cfloat
        direction_angle:: Cfloat
        speed::Cfloat
        size::Cfloat
        color::UInt32
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


module MyModelExamples

    using ..MyModels

    export ctrlState, simState, aAgent, bAgent, stepStep

    aAgent  = Agent(0.3, 0.3, 0.9, 0.01, 0.1, 0xff3c3232)
    bAgent  = Agent(0.6, 0.6, 0.9, 0.02, 0.15, 0xff3c3232)

    ctrlState = ControlState(Cfloat[sin(x) for x in 0:0.05:2pi], false,0.9, 10.0, 5)
    stepStep = SimulationStep(1, [aAgent, bAgent], 0.1)
    simState = SimulationState(stepStep)

    @show typeof(stepStep.agent_list)
    
end


    
if abspath(PROGRAM_FILE) == @__FILE__
    using .MyModelExamples
    @info "ModelExamples" aAgent bAgent ctrlState simState stepStep
end