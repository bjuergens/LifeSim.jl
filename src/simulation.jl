
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

    "process collision between agents by updating their position so they touch each other without overlapping"
    function collision(agent1::Agent, agent2::Agent)
        move_dist =  (agent1.size + agent2.size - distance(agent1.pos - agent2.pos)) / 2
        if move_dist < Ɛ
            @warn "negative move dist -> unexpected results" move_dist
        end
        move_vec = stretch_to_length(agent1.pos - agent2.pos, move_dist)
        ratio = (agent1.size^2) / (agent2.size^2)
        agent1.pos = agent1.pos + (move_vec / ratio)
        agent2.pos = agent2.pos - (move_vec * ratio)
    end

    function update_agents(simStep::SimulationStep, ctrlState::ControlState)
        agent_list_individually = []

        for agent in simStep.agent_list
            pos_new = move_in_direction(agent.pos, agent.direction_angle, agent.speed)

            agent_pos_x::Cfloat = clip(pos_new.x, agent.size, 1.0 - 2agent.size)
            agent_pos_y::Cfloat = clip(pos_new.y, agent.size, 1.0 - 2agent.size) # todo: fix stackoverflow that occurs when this is not explicitly typed. 
            
            if agent.id == 2
                a_direction_angle = agent.direction_angle + 0.05
            else
                a_direction_angle = agent.direction_angle - 0.05
            end 
            a_direction_angle = wrap(a_direction_angle, -pi, 2pi)            

            push!(agent_list_individually, Agent(Vec2(agent_pos_x, agent_pos_y), a_direction_angle, agent.speed , agent.size, agent.color, agent.id))
        end

        for (agent1, agent2) in combinations(agent_list_individually, 2)

            dist = distance(agent1.pos, agent2.pos)

            if dist < 0.00001
                @warn "dist ist very low" dist
                continue
            end
            
            if dist < agent1.size + agent2.size
                collision(agent1, agent2)
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

module LinTests
export doTest
using Test
using ..LSSimulation
using ..LSModelExamples
using ..LSLin

function run_headless(max_time = .5)
    test_ctrlState = deepcopy(ctrlState)
    test_simState = deepcopy(simState)
    ctrlThread = Threads.@spawn begin
        sleep(max_time) 
        test_ctrlState.is_stop = true
    end
    simulationLoop!(Ref(test_simState), test_ctrlState)
    wait(ctrlThread)
    return test_simState.last_step[].num_step
end


function test_collision(pos1, pos2, size1, size2)
    tAgent1 = deepcopy(aAgent)
    tAgent2 = deepcopy(bAgent)
    tAgent1.pos = pos1
    tAgent2.pos = pos2
    tAgent1.size = size1
    tAgent2.size = size2
    pre_dist = distance(tAgent1.pos, tAgent2.pos)
    LSSimulation.collision(tAgent1, tAgent2)

    # since since their distance was smaller than their sumed sized, they did move
    @test distance(tAgent1.pos, tAgent2.pos) > pre_dist
    @test distance(tAgent1.pos, pos1) > 0.01

    # both got move in exact opposite directions
    @test direction(tAgent1.pos, pos1) ≈ direction(tAgent2.pos, pos2) - pi

    # because size is equal, both got moved by same amount
    @test distance(tAgent1.pos, pos1) ≈ distance(tAgent2.pos, pos2) 

    # after each collision they should exactly touch
    @test distance(tAgent1.pos, tAgent2.pos) ≈ tAgent1.size + tAgent2.size
end

function doTest()
    @testset "simtest" begin
        @test 1+1==2  # canary
        @test run_headless() > 5
        test_collision(Vec2(0.35,0.3), Vec2(0.3,0.35), 0.5, 0.5)
        test_collision(Vec2(0.35,0.3), Vec2(0.3,0.35), 0.8, 0.8)
        test_collision(Vec2(0.33,0.3), Vec2(0.33,0.35), 0.8, 0.8)
    end
end
end

if abspath(PROGRAM_FILE) == @__FILE__
    using .LinTests
    using .LSModelExamples
    using .LSSimulation
    doTest()

    do_open = false
    if do_open
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
