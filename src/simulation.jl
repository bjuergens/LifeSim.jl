
if abspath(PROGRAM_FILE) == @__FILE__
    include("models.jl") 
end

module MySimulation
    export simulationLoop!

    using ..MyModels

    function simulationLoop!(simState_transfer::Ref{SimulationState}, ctrlState::ControlState)
        @info "simulationLoop!..."

        simState = deepcopy(simState_transfer[])
        last_time = Base.time_ns()
        while !ctrlState.is_stop
            simState.num_age += 1

            if ( 0 == mod(floor(simState.num_age / 10), 2))
                simState.agent1.pos_x += 0.01
                simState.agent1.pos_y += 0.01
            else
                simState.agent1.pos_x -= 0.01
                simState.agent1.pos_y -= 0.01
            end
            
            simState_transfer[] = deepcopy(simState)
            new_time = Base.time_ns()
            elapsed_time = new_time-last_time
            simState.last_frame_time_ms = elapsed_time/1000
            time_to_wait_s = (ctrlState.min_frametime_ms - simState.last_frame_time_ms) / 1000
            if time_to_wait_s>0
                sleep(time_to_wait_s)
                new_time = Base.time_ns()
            end
            last_time = new_time

            
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
    wait(ctrlThread)
    @info simState
end
