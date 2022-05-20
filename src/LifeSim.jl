
using Revise

module LifeSim

    export main

    include("lin.jl")
    include("neural.jl")
    include("models.jl")
    include("evolution.jl") 
    include("simulation.jl")
    include("gui.jl")
    
    # using StaticArrays
    using .LSModels
    using .LSGui
    using .LSSimulation
    using .LSModelExamples
    using .LSNaturalNet
    using .LSEvolution
    

    using CImGui: IM_COL32

    function update_from_gui!(ctrl_state_to_sim::Ref{ControlState}, ctrl_state_from_gui::Ref{ControlState})
        lock(lk_ctrl)
        try
            #= note:
             this lock is pretty useless ATM, since the gui writes to ctrlState without a lock. 
             For now it's not an issue, since this copy is atomic (hopefully)
            =#
            ctrl_state_to_sim[] =  deepcopy(ctrl_state_from_gui[])
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


    function update_loop(ctrl_state_to_sim::Ref{ControlState},   ctrl_state_from_gui::Ref{ControlState}, 
                         sim_state_to_gui::Ref{SimulationState}, sim_state_from_sim::Ref{SimulationState})
        ctrl_state_from_gui[].is_stop = false
        @async while true
            update_from_sim!(sim_state_to_gui, sim_state_from_sim)
            update_from_gui!(ctrl_state_to_sim, ctrl_state_from_gui)
            ctrl_state_from_gui[].is_stop && break
            yield()
            sleep(0.016)
        end
    end

    
    function main()

        @info "running gui with some dummy-data for debugging..."
        ctrl_state_from_gui = ControlState()
        ref_ctrl_state_from_gui = Ref(ctrl_state_from_gui)
        ref_ctrl_state_to_simulation = Ref(ctrl_state_from_gui)


        sim_state_from_sim = initial_sim_state(ctrlState=ctrl_state_from_gui)
        ref_sim_state_to_gui = Ref(deepcopy(sim_state_from_sim))
        ref_sim_state_to_simulation = Ref(sim_state_from_sim)


        @info "starting render loop..."
        t_render, _ = LS_render_loop!(ref_ctrl_state_from_gui, ref_sim_state_to_gui, Ref(GuiState(false)) ,  true)
        @info "starting update loop..."
        t_update = update_loop(ref_ctrl_state_to_simulation, ref_ctrl_state_from_gui,
                               ref_sim_state_to_gui,         ref_sim_state_to_simulation)  

        @info "starting work thread..."
        workThread = Threads.@spawn simulationLoop!($ref_sim_state_to_simulation, $ref_ctrl_state_to_simulation)

        @info "Threads " Threads.nthreads() Threads.threadid()

        wait(t_render)
        #ctrl_state_from_gui.is_stop = true
        ref_ctrl_state_from_gui[].is_stop = true
        #ref_ctrl_state_to_simulation[].is_stop = true
        wait(t_update)
        wait(workThread)

        @info "num simulation steps " ref_sim_state_to_simulation[].last_step[].num_step
        
    end
end


if abspath(PROGRAM_FILE) == @__FILE__
    using .LifeSim
    @warn "hotreloading disabled.
    If you want hot reloading, import this as a package e.g. with 
    
    julia -e \"using LifeSim; main()\"
    "
    main()
end