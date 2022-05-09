
    using CImGui

    render_source = joinpath(pathof(CImGui), "..", "..", "examples", "Renderer.jl")
    @show render_source
    include(render_source)
    using .Renderer


    include("models.jl") 
    using .MyModels


    function drawAgent!(draw_list, aAgent::Agent)
        canvas_pos = ImVec2(aCanvas.pos_x, aCanvas.pos_y)
        @show aCanvas
        CImGui.AddRectFilled(draw_list, 
        ImVec2(canvas_pos.x + 0.3*aCanvas.size_x, canvas_pos.y + 0.3* aCanvas.size_y), 
        ImVec2(canvas_pos.x + 0.4*aCanvas.size_x, canvas_pos.y + 0.4* aCanvas.size_y), 
        IM_COL32(0, 255, 255, 255)
    )
        draw_pos_x = aCanvas.pos_x+ aAgent.pos_x * aCanvas.size_x
        draw_pos_y = aCanvas.pos_y+ aAgent.pos_y * aCanvas.size_y
        CImGui.AddRectFilled(draw_list, 
            ImVec2(draw_pos_x-aAgent.size, draw_pos_y-aAgent.size), 
            ImVec2(draw_pos_x+aAgent.size, draw_pos_y+aAgent.size), 
            IM_COL32(0, 0, 255, 255)
        )
        @show draw_pos_x
        @show draw_pos_y
    end



    function drawAgent2!(draw_list, canvas_pos, canvas_size, aAgent::Agent)

        CImGui.AddRectFilled(draw_list, 
            ImVec2(
                canvas_pos.x + ((aAgent.pos_x - aAgent.size) * canvas_size.x) , 
                canvas_pos.y + ((aAgent.pos_y - aAgent.size) * canvas_size.y)
            ), 
            ImVec2(
                canvas_pos.x + ((aAgent.pos_x + aAgent.size ) * canvas_size.x) , 
                canvas_pos.y + ((aAgent.pos_y + aAgent.size ) * canvas_size.y)+ aAgent.size
            ), 
            IM_COL32(0, 255, 255, 255))
    end

    using CImGui: ImVec2, ImVec4, IM_COL32, ImU32

    col=Cfloat[1.0,1.0,0.4,1.0]

    # this is the UI function, whenever the structure of `MyStates` is changed, 
    # the corresponding changes should be applied
    function ui(controlState::ControlState, simState::Ref{SimulationState})
        # CImGui.SetNextWindowSize((300, 200), CImGui.ImGuiCond_FirstUseEver)
        CImGui.SetNextWindowSize((300, 200), CImGui.ImGuiCond_Once)
        CImGui.Begin("CanvasWindow")
            draw_list = CImGui.GetWindowDrawList()

            col32 = CImGui.ColorConvertFloat4ToU32(ImVec4(col...))
            x= 10
            y= 15
            # CImGui.AddRectFilled(draw_list, ImVec2(x, y), ImVec2(x+10, y+10), col32);     

            CImGui.Text("Canvas: ")
            CImGui.Separator()
            
            canvas_pos = CImGui.GetCursorScreenPos()            # ImDrawList API uses screen coordinates!
            canvas_size = CImGui.GetContentRegionAvail()        # resize canvas to what's available

            cx, cy = canvas_size.x, canvas_size.y - 100
            cx < 50.0 && (cx = 50.0)
            cy < 50.0 && (cy = 50.0)
            canvas_size = ImVec2(cx, cy)

            CImGui.AddRectFilledMultiColor(draw_list, 
                canvas_pos, 
                ImVec2(canvas_pos.x + canvas_size.x, canvas_pos.y + canvas_size.y), 
                IM_COL32(150, 50, 50, 255), 
                IM_COL32(50, 50, 60, 255), 
                IM_COL32(60, 60, 70, 255), 
                IM_COL32(50, 50, 60, 255)
            )
            CImGui.AddRect(draw_list, canvas_pos, ImVec2(canvas_pos.x + canvas_size.x, canvas_pos.y + canvas_size.y), IM_COL32(255, 255, 255, 255))
            
                CImGui.AddRectFilled(draw_list, 
                ImVec2(canvas_pos.x + 0.6*canvas_size.x, canvas_pos.y + 0.6* canvas_size.y), 
                ImVec2(canvas_pos.x + 0.7*canvas_size.x, canvas_pos.y + 0.7* canvas_size.y), 
                IM_COL32(255, 0, 255, 255)
            )
            drawAgent2!(draw_list, canvas_pos, canvas_size, simState[].agent1)
            drawAgent2!(draw_list, canvas_pos, canvas_size, simState[].agent2)
            # add invis control behind canvas so following controls get placed correctly
            CImGui.InvisibleButton("canvas", canvas_size) 
            
            
            CImGui.Separator()

            CImGui.Text(string("Frametime: ", simState[].last_frame_time_ms, "ms"))
            
            min_frametime_ms = Ref(controlState.min_frametime_ms)
            CImGui.SliderFloat("min_frame_time", min_frametime_ms, 0.0, 100.0, "time = %.3f ms")
            controlState.min_frametime_ms = min_frametime_ms[]

        CImGui.End()

        CImGui.SetNextWindowSize((300, 400), CImGui.ImGuiCond_Once)
        CImGui.Begin("OptionsWindow")
        
            is_connected = Ref(controlState.is_stop)
            float_ref = Ref(controlState.afloat)
            CImGui.SliderFloat("slider float", float_ref, 0.0, 2.0, "ratio = %.3f")
            controlState.afloat = float_ref[]

            if CImGui.Checkbox("connected?", is_connected)
                controlState.is_stop = !is_connected[]
            end
            CImGui.PlotLines("sine wave", controlState.arr, length(controlState.arr))
        CImGui.End()
    end

    function start_render_loop!(ctrlState::ControlState, simState::Ref{SimulationState})
        println("starting render loop...")
        return Renderer.render(()->ui(ctrlState, simState), width = 800, height = 600, title = "A simple UI")
    end

    function aaa()

        println("running gui with some dummy-data for debugging...")
        function infinite_loop(state::ControlState)
            state.is_stop = false
            @async while true
                @show state.is_stop
                state.is_stop && break
                push!(state.arr, popat!(state.arr, 1) * state.afloat)
                yield()
            end
        end
        ctrlState = ControlState(Cfloat[sin(x) for x in 0:0.05:2pi], false,0.9, 10.0)
        simState = Ref(SimulationState(
            1,
            Agent(0.3, 0.3, 0.9, 0.1),
            Agent(0.6, 0.6, 0.9, 0.1), 
            0.0
        ))
        t_render = start_render_loop!(ctrlState, simState)
        println("starting dummy update loop...")
        t_update = infinite_loop(ctrlState)
        !isinteractive() && wait(t_render)
        #!isinteractive() && wait(t_update)
    end 


if abspath(PROGRAM_FILE) == @__FILE__
    # using .MyCimGui
    # MyCimGui.aaa()
    aaa()
end