
if abspath(PROGRAM_FILE) == @__FILE__
    include("lin.jl") 
    include("models.jl") 
end

module LSSimulation
    export simulationLoop!, lk_sim, lk_ctrl

    using ..LSModels
    using ..LSLin

    using CImGui: IM_COL32
    using Distances: Euclidean
    using Combinatorics: combinations

    lk_sim = ReentrantLock()
    lk_ctrl = ReentrantLock()

    COL_INERT = IM_COL32(40,50,40,255)
    COL_ACTIV = IM_COL32(255,50,40,255)
    COL_COLLISION = IM_COL32(255,255,40,255)

    function update_agents(simStep::SimulationStep, ctrlState::ControlState)
        agent_list_individually = []

        for agent in simStep.agent_list
            pos_new = move_in_direction(agent.pos, agent.direction_angle, agent.speed)

            agent_pos_x = clip(pos_new.x, agent.size, 1.0 - 2agent.size)
            agent_pos_y = clip(pos_new.y, agent.size, 1.0 - 2agent.size)
            
            if agent.id == 2
                a_direction_angle = agent.direction_angle + 0.05
            else
                a_direction_angle = agent.direction_angle - 0.05
            end 
            a_direction_angle = wrap(a_direction_angle, -pi, 2pi)

            push!(agent_list_individually, Agent(Vec2(agent_pos_x, agent_pos_y), a_direction_angle, agent.speed , agent.size, agent.color, agent.id))
        end

        for (agent1, agent2) in combinations(agent_list_individually, 2)

            dist = Euclidean()((agent1.pos.x,agent1.pos.y), (agent2.pos.x,agent2.pos.y))

            if dist < 0.00001
                @warn "dist ist very low" dist
                continue
            end
            
            if dist < agent1.size + agent2.size
                move_dist =  agent1.size + agent2.size - dist
                d_x = agent1.pos.x - agent2.pos.x
                d_y = agent1.pos.y - agent2.pos.y
                d_length = sqrt(d_x*d_x+d_y*d_y)
                norm_direction = (d_x/d_length,d_y/d_length) 

                move_vec = (x=move_dist*norm_direction[1],y=move_dist*norm_direction[2])
                ratio = (agent1.size^2) / (agent2.size^2)

                agent1.pos = Vec2(agent1.pos.x + (move_vec.x / ratio), 
                                  agent1.pos.y + (move_vec.y / ratio))
                agent2.pos = Vec2(agent2.pos.x - (move_vec.x * ratio),
                                  agent2.pos.y - (move_vec.y * ratio))
            end
        end

        if 0 == mod(simStep.num_step, 100)
            @info "doing evolution-step"

            # todo: kill some agents
            # todo: make some cross-overs
            # todo: make some mutation
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
                # sleep is efficient but inacurate 
                # https://discourse.julialang.org/t/accuracy-of-sleep/5546
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
    using .LSModelExamples
    using .LSSimulation
    if cli_test
        test_console()
    else
        include("gui.jl")
        using .LSGui
        using .LSModels
        list = simState.last_step[].agent_list

        cAgent = Agent(Vec2(0.2, 0.3), pi/2, 0.01, 0.05, list[1].color ,3)
        push!(list, cAgent)

        sim_ref = Ref(simState)
        t_render, _ = start_render_loop!(ctrlState, sim_ref)
        @info "starting simloop loop..."
        workThread = Threads.@spawn simulationLoop!($sim_ref, $ctrlState)
        !isinteractive() && wait(t_render)
        @info "gui done"
        ctrlState.is_stop = true
        wait(workThread)
        @info "done... done"
    end

end
