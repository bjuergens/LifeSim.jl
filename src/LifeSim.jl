

# include("models.jl")
# using ..models


include("gui.jl")

# using ..MyCimGui: start_render_loop!  as my_renderloop

# using ..MyCimGui


lk_sim = ReentrantLock()
lk_ctrl = ReentrantLock()

function update!(state::ControlState)
    
    lock(lk_sim)
    try
        state_copy = deepcopy(state)
        push!(state.arr, popat!(state.arr, 51) * state.afloat)
    finally
        unlock(lk_sim)
    end
end


function simWork!(simState::SimulationState, ctrlState::ControlState)
    
    last_time = Base.time_ns()
    while !ctrlState.is_stop
        simState.num_age += 1

        aaa = mod(floor(simState.num_age / 10), 2)
        if (aaa == 0)
            simState.agent1.pos_x += 0.01
            simState.agent1.pos_y += 0.01
        else
            simState.agent1.pos_x -= 0.01
            simState.agent1.pos_y -= 0.01
        end
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
end


function update!(ctrl_state_to_sim::Ref{ControlState}, ctrl_state_from_sim::ControlState)
    
    lock(lk_ctrl)
    try
        ctrl_state_to_sim[] =  deepcopy(ctrl_state_from_sim)
    finally
        unlock(lk_ctrl)
    end
end

function update!(sim_state_to_gui::Ref{SimulationState}, sim_state_from_sim::SimulationState)
    
    lock(lk_sim)
    try
        sim_state_to_gui[] =  deepcopy(sim_state_from_sim)
    finally
        unlock(lk_sim)
    end
end


function infinite_loop(ctrlState::ControlState, sim_state_to_gui::Ref{SimulationState}, sim_state_from_sim::SimulationState)
    ctrlState.is_stop = false
    @async while true
        ctrlState.is_stop && break
        update!(ctrlState)
        update!(sim_state_to_gui, sim_state_from_sim)
        yield()
    end
end


function main()


    println("running gui with some dummy-data for debugging...")

    ctrlState = ControlState(Cfloat[sin(x) for x in 0:0.05:2pi], false,0.9, 10.0)
    sim_state_from_sim = SimulationState(
        1, 
        Agent(0.3, 0.3, 0.9, 0.1),
        Agent(0.6, 0.6, 0.9, 0.1),
        0.0
    )
    ref_sim_state_to_gui = Ref(deepcopy(sim_state_from_sim))

    println("starting render loop...")
    
    # t_render = Renderer.render(()->ui(ctrlState, ref_sim_state_to_gui), width = 800, height = 600, title = "A simple UI")
    
    t_render = start_render_loop!(ctrlState, ref_sim_state_to_gui)
    println("starting dummy update loop...")

    t_update = infinite_loop(ctrlState, ref_sim_state_to_gui, sim_state_from_sim)


    workThread = Threads.@spawn simWork!($sim_state_from_sim, $ctrlState)

    @show Threads.nthreads() Threads.threadid()

    !isinteractive() && wait(t_render)
    ctrlState.is_stop = true
    !isinteractive() && wait(t_update)
    ctrlState.is_stop = true
    wait(workThread)

    end 

main()