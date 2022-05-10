
if abspath(PROGRAM_FILE) == @__FILE__
    include("models.jl") 
end

module MySimulation
    export simulationLoop!, lk_sim, lk_ctrl

    using ..MyModels

    using CImGui: IM_COL32
    using Distances: Euclidean

    lk_sim = ReentrantLock()
    lk_ctrl = ReentrantLock()

    

    COL_INERT = IM_COL32(40,50,40,255)
    COL_ACTIV = IM_COL32(255,50,40,255)
    COL_COLLISION = IM_COL32(255,255,40,255)

    function wrap(value, min, max)
        value =  value > max ? value - (max - min) : value

        if value < min
            value += max
        end
        return value
    end

    function limit(value, min, max)
        
        if value > max 
            return  max, false
        end

        if value < min
            return min, false
        end
        return value, true
    end
    

    function update_agents(simStep::SimulationStep, ctrlState::ControlState)
        agent_list_individually = []

        # todo: collision with walls
        # --> dann bewegung mit direction_angle
        # todo: collision mit mobs

        for agent in simStep.agent_list
            agent_pos_x = agent.pos_x + sin(agent.direction_angle) * agent.speed
            agent_pos_y = agent.pos_y + cos(agent.direction_angle) *agent.speed

            agent_pos_x, inside_x = limit(agent_pos_x, agent.size, 1.0 - agent.size)
            agent_pos_y, inside_y = limit(agent_pos_y, agent.size, 1.0 - agent.size)
            
            a_direction_angle = agent.direction_angle + 0.05
            a_direction_angle = wrap(a_direction_angle, -pi, pi)

            if inside_x && inside_y
                color = COL_INERT
            else
                color = COL_ACTIV
            end
            

            push!(agent_list_individually, Agent(agent_pos_x, agent_pos_y, a_direction_angle, agent.speed , agent.size, color))
        end

        agent_list_final = []
        for (agent1, agent2) in Iterators.product(agent_list_individually,agent_list_individually)

            if agent1==agent2
                continue
            end
            dist = Euclidean()((agent1.pos_x,agent1.pos_y), (agent2.pos_x,agent2.pos_y))
            
            if dist < agent1.size + agent2.size
                agent1.color = COL_COLLISION
                # todo: give id to agents, and only do detection in one direction
                # todo: move agent appart from each other, while the heavier one is moved less.
            end
        end

        return agent_list_individually
    end

    function simulationLoop!(simState_transfer::Ref{SimulationState}, ctrlState::ControlState)
        @info "simulationLoop!..."

        simState = simState_transfer[].last_step[]
        last_time_ns = Base.time_ns()
        while !ctrlState.is_stop
            
            agentList = update_agents(simState, ctrlState)

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

function test_console()
    ctrlThread = Threads.@spawn stop_after(1.0)
    simulationLoop!(Ref(simState), ctrlState)
    @info simState.last_step[].num_step
    wait(ctrlThread)
    @info simState.last_step[].num_step
    @info simState
end

if abspath(PROGRAM_FILE) == @__FILE__
    cli_test = false
    function stop_after(time_s)
        @info "stop_after..."
        sleep(time_s)
        ctrlState.is_stop = true
        @info "stop_after... done" 
    end
    using .MyModelExamples
    using .MySimulation
    if cli_test
        test_console()
    else
        include("gui.jl")
        using .MyGui
        using .MyModels
        sim_ref = Ref(simState)
        t_render = start_render_loop!(ctrlState, sim_ref)
        @info "starting simloop loop..."
        workThread = Threads.@spawn simulationLoop!($sim_ref, $ctrlState)
        !isinteractive() && wait(t_render)
        @info "gui done"
        ctrlState.is_stop = true
        wait(workThread)
        @info "done... done"
    end

end
