
module MyModels
    export Agent
    export SimulationState, ControlState

    mutable struct Agent
        pos_x::Cfloat
        pos_y::Cfloat
        direction_angle:: Cfloat
        size::Cfloat
    end

    mutable struct SimulationState
        num_age::Int
        agent1::Agent
        agent2::Agent
        last_frame_time_ms::Float64
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

    export ctrlState, simState, aAgent, bAgent

    aAgent  = Agent(0.3, 0.3, 0.9, 0.1)
    bAgent  = Agent(0.6, 0.6, 0.9, 0.1)

    ctrlState = ControlState(Cfloat[sin(x) for x in 0:0.05:2pi], false,0.9, 10.0, 5)
    simState = SimulationState(1, aAgent, bAgent, 0.0
    )
end


    
if abspath(PROGRAM_FILE) == @__FILE__
    using .MyModelExamples
    @info aAgent bAgent ctrlState simState
end