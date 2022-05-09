
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

        simState_old = deepcopy(simState_transfer[])
        last_time = Base.time_ns()
        while !ctrlState.is_stop
            
            num_age = simState_old.num_age + 1
            simState_agent1_pos_x = 0
            simState_agent1_pos_y = 0
            if ( 0 == mod(floor(num_age / 10), 2))
                simState_agent1_pos_x = simState_old.agent1.pos_x + 0.01
                simState_agent1_pos_y = simState_old.agent1.pos_y + 0.01
            else
                simState_agent1_pos_x = simState_old.agent1.pos_x - 0.01
                simState_agent1_pos_y = simState_old.agent1.pos_y - 0.01
            end
            new_time = Base.time_ns()
            elapsed_time = new_time-last_time
            last_frame_time_ms = elapsed_time/1000
            time_to_wait_s = (ctrlState.min_frametime_ms - last_frame_time_ms) / 1000
            if time_to_wait_s>0
                sleep(time_to_wait_s)
            end


            lock(lk_sim)
            try
                simState_transfer[].num_age = num_age
                simState_transfer[].agent1 = Agent(simState_agent1_pos_x, simState_agent1_pos_y, simState_old.agent1.direction_angle, simState_old.agent1.size )
                simState_transfer[].agent2 = Agent(simState_old.agent2.pos_x, simState_old.agent2.pos_y, simState_old.agent2.direction_angle, simState_old.agent2.size )
                simState_transfer[].last_frame_time_ms = last_frame_time_ms
                simState_old = deepcopy(simState_transfer[])
            finally
                unlock(lk_sim)
            end

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
    @info simState.num_age
    wait(ctrlThread)
    @info simState.num_age
    @info simState
end
