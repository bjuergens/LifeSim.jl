
module MyModels
    export Agent, makeAgent
    export SimulationState, ControlState, SimulationStep

    using CImGui: IM_COL32

    mutable struct Agent
        pos_x::Cfloat
        pos_y::Cfloat
        direction_angle:: Cfloat
        speed::Cfloat
        size::Cfloat
        color::UInt32
        id::Int
    end

    function makeAgent(id, genome)
        red = mod(id*10, 255 )
        green = mod(-id*10, 255 )
       return Agent(genome[1], genome[2], genome[3], genome[4], genome[5],  IM_COL32(red,green,0,255) , id)
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

    using CImGui: IM_COL32
    export ctrlState, simState, aAgent, bAgent, stepStep

    aGenome = [0.3, 0.3, pi/2, 0.01, 0.11]
    bGenome = [0.6, 0.6, 2*pi, 0.02, 0.13]

    aAgent = makeAgent(1,aGenome)
    bAgent = makeAgent(10,bGenome)

    ctrlState = ControlState(Cfloat[sin(x) for x in 0:0.05:2pi], false,0.9, 50.0, 5)
    stepStep = SimulationStep(1, [aAgent, bAgent], 0.1)
    simState = SimulationState(stepStep)

    @show typeof(stepStep.agent_list)
    
end


    
if abspath(PROGRAM_FILE) == @__FILE__
    using .MyModelExamples
    @info "ModelExamples" aAgent bAgent ctrlState simState stepStep
end