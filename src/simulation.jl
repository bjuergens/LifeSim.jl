
if abspath(PROGRAM_FILE) == @__FILE__
    include("models.jl") 
end

module MySimulation
    export simulationLoop!, lk_sim, lk_ctrl

    using ..MyModels

    lk_sim = ReentrantLock()
    lk_ctrl = ReentrantLock()

    function simulationLoop!(simState_transfer::Ref{SimulationState}, ctrlState::ControlState)
        @info "simulationLoop!..."

        #simState_old = deepcopy(simState_transfer[])
        simState = simState_transfer[].last_step[]
        last_time = Base.time_ns()
        while !ctrlState.is_stop
            
            num_age = simState.num_step + 1
            simState_agent1_pos_x = 0
            simState_agent1_pos_y = 0
            if ( 0 == mod(floor(num_age / 10), 2))
                simState_agent1_pos_x = simState.agent_list[1].pos_x + 0.01
                simState_agent1_pos_y = simState.agent_list[1].pos_y + 0.01
            else
                simState_agent1_pos_x = simState.agent_list[1].pos_x - 0.01
                simState_agent1_pos_y = simState.agent_list[1].pos_y - 0.01
            end

            
            new_time = Base.time_ns()
            elapsed_time = new_time-last_time
            last_frame_time_ms = elapsed_time/1000
            time_to_wait_s = (ctrlState.min_frametime_ms - last_frame_time_ms) / 1000
            if time_to_wait_s>0
                sleep(time_to_wait_s)
            end

            agentList = [ 
                Agent(simState_agent1_pos_x, simState_agent1_pos_y, simState.agent_list[1].direction_angle, simState.agent_list[1].size ),
                Agent(simState.agent_list[2].pos_x, simState.agent_list[2].pos_y, simState.agent_list[2].direction_angle, simState.agent_list[2].size)
            ]
            lock(lk_sim)
            try
                simState_transfer[].last_step=Ref(simState)
            finally
                unlock(lk_sim)
            end
            simState = SimulationStep(num_age, agentList, last_frame_time_ms)

            last_time = Base.time_ns()

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
