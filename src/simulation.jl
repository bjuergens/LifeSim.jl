
if abspath(PROGRAM_FILE) == @__FILE__
    include("models.jl") 
end

module MySimulation
    export simulationLoop!, lk_sim, lk_ctrl

    using ..MyModels

    lk_sim = ReentrantLock()
    lk_ctrl = ReentrantLock()

    function get_step_agents(simStep::SimulationStep, ctrlState::ControlState)
        agent_list_result = []

        for agent in simStep.agent_list
            if ( 0 == mod(floor(simStep.num_step / 10), 2))
                agent_pos_x = agent.pos_x + 0.01
                agent_pos_y = agent.pos_y + 0.01
            else
                agent_pos_x = agent.pos_x - 0.01
                agent_pos_y = agent.pos_y - 0.01
            end
            push!(agent_list_result, Agent(agent_pos_x, agent_pos_y, agent.direction_angle, agent.size))
        end

        return agent_list_result
    end

    function simulationLoop!(simState_transfer::Ref{SimulationState}, ctrlState::ControlState)
        @info "simulationLoop!..."

        simState = simState_transfer[].last_step[]
        last_time_ns = Base.time_ns()
        while !ctrlState.is_stop
            
            agentList = get_step_agents(simState, ctrlState)

            last_frame_time_ms = (Base.time_ns()-last_time_ns) / 1000
            time_to_wait_s = (ctrlState.min_frametime_ms - last_frame_time_ms) / 1000
            if time_to_wait_s > 0
                sleep(time_to_wait_s)
            end

            lock(lk_sim)
            try
                simState_transfer[].last_step=Ref(simState)
            finally
                unlock(lk_sim)
            end
            simState = SimulationStep(simState.num_step + 1, agentList, last_frame_time_ms)

            last_time_ns = Base.time_ns()
        end
    
        @info "simulationLoop!... done"
    end
end



if abspath(PROGRAM_FILE) == @__FILE__
    using .MyModelExamples
    using .MySimulation
    
    function stop_after(time_s)
        @info "stop_after..."
        sleep(time_s)
        ctrlState.is_stop = true
        @info "stop_after... done" 
    end
    ctrlThread = Threads.@spawn stop_after(1.0)
    simulationLoop!(Ref(simState), ctrlState)
    @info simState.last_step[].num_step
    wait(ctrlThread)
    @info simState.last_step[].num_step
    @info simState
end
