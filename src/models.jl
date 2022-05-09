
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
    end
end