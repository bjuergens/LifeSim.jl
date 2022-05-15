
if abspath(PROGRAM_FILE) == @__FILE__
    include("lin.jl") 
    include("models.jl") 
end

module LSSimulation
    export simulationLoop!, lk_sim, lk_ctrl

    using Revise
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
    WORLD_CENTER = Vec2(0.5,0.5)

    # MAX_ROTATE = 0.05 # max rotation in rad per timestep
    MAX_ROTATE = 0.15 # max rotation in rad per timestep

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

    struct SensorInput
        compass_north::Cfloat ## direction to y-axis with respect to current direction
        compass_center::Cfloat ## direction to world middle with respect to current direction
    end

    function makeSensorInput(aAgent)
       
        # direction-angle points east because that's where the x-axis is
        compass_north = aAgent.direction_angle + pi/2
        
        
        abs_direction_to_center = direction(aAgent.pos, WORLD_CENTER)
        compass_center =  abs_direction_to_center - aAgent.direction_angle

        # @show WORLD_CENTER aAgent.pos aAgent.direction_angle abs_direction_to_center compass_center
        return SensorInput(
            wrap(compass_north,0, 2pi), 
            wrap(compass_center,0, 2pi))
    end

    struct ActionIntention
        rotate::Cfloat ## relative desired rotation, in [-1,1]
    end

    function agent_think(input::SensorInput)

        # when center is to the left , move left
        # when center is to the right, move right
        if input.compass_center < pi
            return ActionIntention(1.0)
        else
            return ActionIntention(-1.0)
        end
    end

    function update_agents(simStep::SimulationStep, ctrlState::ControlState)
        agent_list_individually = []

        for agent in simStep.agent_list
            pos_new = move_in_direction(agent.pos, agent.direction_angle, agent.speed)

            agent_pos_x::Cfloat = clip(pos_new.x, agent.size, 1.0 - 2agent.size)
            agent_pos_y::Cfloat = clip(pos_new.y, agent.size, 1.0 - 2agent.size) # todo: fix stackoverflow that occurs when this is not explicitly typed. 
            
            sensor = makeSensorInput(agent)
            desire = agent_think(sensor)

            rotation =  + desire.rotate * MAX_ROTATE          
            a_direction_angle = wrap(agent.direction_angle+rotation, 0, 2pi)            

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

    "update internal simulation stat. publishes result to other threads. handles some ctrl-task"
    function doSimulationStep(last_time_ns, simState_transfer, ctrlState, lk_sim, simState)
        # first part: update actual state
        agentList = update_agents(simState, ctrlState)


        # second part: perform meta-tasks around simulation step
        
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
        return SimulationStep(simState.num_step + 1, agentList, last_frame_time_ms)
    end


    function simulationLoop!(simState_transfer::Ref{SimulationState}, ctrlState_transfer::Ref{ControlState}, hotloading=true)
        @info "simulationLoop!..."

        ctrlState = ctrlState_transfer[]
        simState = simState_transfer[].last_step[]
        last_request_revise = ctrlState.request_revise
        last_request_play = ctrlState.request_play
        last_request_pause = ctrlState.request_pause
        is_paused = false
        while !ctrlState.is_stop
            # some things must be handled outside doSimulationStep and thus can not be hot-reloaded
            # these are: handle the reload and passing data between iterations.  

            last_time_ns = Base.time_ns()
            ctrlState = ctrlState_transfer[]
            if last_request_revise != ctrlState.request_revise
                if last_request_revise > ctrlState.request_revise
                    @warn "unexpected request from the future" last_request_revise > ctrlState.request_revise
                end
                @info "revise request received"
                last_request_revise = ctrlState.request_revise
                revise()
            end
            if last_request_play != ctrlState.request_play
                @info "request_play received"
                last_request_play = ctrlState.request_play
                is_paused = false
            end
            if last_request_pause != ctrlState.request_pause
                @info "request_pause received"
                last_request_pause = ctrlState.request_pause
                is_paused = true
            end


            if is_paused
                sleep(0.1)
                continue
            end

            if hotloading
                simState = Base.invokelatest(doSimulationStep,last_time_ns, simState_transfer, ctrlState, lk_sim, simState)
            else
                simState =                   doSimulationStep(last_time_ns, simState_transfer, ctrlState, lk_sim, simState)
            end
        end
        @info "simulationLoop!... done"
    end
end

module SimTests
export doTest
using Test
using ..LSSimulation
using ..LSModelExamples
using ..LSLin

function run_headless(max_time)
    test_ctrlState = deepcopy(ctrlState)
    test_simState = deepcopy(simState)
    ctrlThread = Threads.@spawn begin
        sleep(max_time) 
        test_ctrlState.is_stop = true
    end
    simulationLoop!(Ref(test_simState), Ref(test_ctrlState), false)
    wait(ctrlThread)
    return test_simState.last_step[].num_step
end

function applyMakeSensor(pos, dir)
    
    tAgent1 = deepcopy(aAgent)
    tAgent1.pos = pos
    tAgent1.direction_angle = dir
    result = LSSimulation.makeSensorInput(tAgent1)
    @test result.compass_north > 0
    return result
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
    @test direction(tAgent1.pos, pos1) ≈ direction(tAgent2.pos, pos2) + pi

    # because size is equal, both got moved by same amount
    @test distance(tAgent1.pos, pos1) ≈ distance(tAgent2.pos, pos2) 

    # after each collision they should exactly touch
    @test distance(tAgent1.pos, tAgent2.pos) ≈ tAgent1.size + tAgent2.size
end

function doTest()
    @testset "simtest" begin
        @test 1+1==2  # canary
        @test run_headless(0.9) > 5
        test_collision(Vec2(0.35,0.3), Vec2(0.3,0.35), 0.5, 0.5)
        test_collision(Vec2(0.35,0.3), Vec2(0.3,0.35), 0.8, 0.8)
        test_collision(Vec2(0.33,0.3), Vec2(0.33,0.35), 0.8, 0.8)

        c = LSSimulation.WORLD_CENTER
        @test applyMakeSensor(c, 0).compass_north ≈ pi/2
        
        # agent is right off center with orientation along x-axis, then the center should be exactly behind it
        @test applyMakeSensor( c + Vec2(0.1,0.0), 0).compass_center ≈ pi
        # center is right in front of agent
        @test applyMakeSensor( c + Vec2(-0.1,0.0), 0).compass_center ≈ 0
        # center is to the left
        @test applyMakeSensor( c + Vec2(0.0,-0.1), 0).compass_center ≈ pi/2
        # center is to the right
        @test applyMakeSensor( c + Vec2(0.0,0.1), 0).compass_center ≈ 3pi/2
        # @test applyMakeSensor(Vec2(0.2,0.2), 0) ≈ LSSimulation.SensorInput(pi/2, pi/4)
    end 
end
end

if abspath(PROGRAM_FILE) == @__FILE__
    using .SimTests
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
