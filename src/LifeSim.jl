
module MyMain

    export main

    include("models.jl")
    include("gui.jl")
    include("simulation.jl")

    using .MyModels
    using .MyGui
    using .MySimulation

    function update_from_gui!(ctrl_state_to_sim::Ref{ControlState}, ctrl_state_from_sim::ControlState)
        lock(lk_ctrl)
        try
            ctrl_state_to_sim[] =  deepcopy(ctrl_state_from_sim)
        finally
            unlock(lk_ctrl)
        end
    end

    function update_from_sim!(sim_state_to_gui::Ref{SimulationState}, sim_state_from_sim::Ref{SimulationState})
        
        lock(lk_sim)
        try
            sim_state_to_gui[] =  deepcopy(sim_state_from_sim[])
        finally
            unlock(lk_sim)
        end
    end


    function infinite_loop(ctrlState::ControlState, sim_state_to_gui::Ref{SimulationState}, sim_state_from_sim::Ref{SimulationState})
        ctrlState.is_stop = false
        @async while true
            ctrlState.is_stop && break
            update_from_sim!(sim_state_to_gui, sim_state_from_sim)
            yield()
        end
    end


    function main()

        # todo: safe copy controlstate to worker in the same safe way as the other way

        @info "running gui with some dummy-data for debugging..."

        ctrlState = ControlState(Cfloat[sin(x) for x in 0:0.05:2pi], false,0.9, 50.0, 5)
        sim_state_from_sim = SimulationState(
            1, 
            Agent(0.3, 0.3, 0.9, 0.1),
            Agent(0.6, 0.6, 0.9, 0.1),
            0.0
        )
        ref_sim_state_to_gui = Ref(deepcopy(sim_state_from_sim))
        ref_sim_state_to_simulation = Ref(sim_state_from_sim)

        @info "starting render loop..."
        t_render = start_render_loop!(ctrlState, ref_sim_state_to_gui)
        @info "starting dummy update loop..."


        t_update = infinite_loop(ctrlState, ref_sim_state_to_gui, ref_sim_state_to_simulation)

        workThread = Threads.@spawn simulationLoop!($ref_sim_state_to_simulation, $ctrlState)

        @info "Threads " Threads.nthreads() Threads.threadid()

        !isinteractive() && wait(t_render)
        ctrlState.is_stop = true
        !isinteractive() && wait(t_update)
        ctrlState.is_stop = true
        wait(workThread)


        @info "num simulation steps " ref_sim_state_to_simulation[].num_age
        @info "final sim state " ref_sim_state_to_simulation[]
    end
end


using .MyMain


main()
