

if abspath(PROGRAM_FILE) == @__FILE__
    include("models.jl") 
end

module MyGui
    export start_render_loop!
    using CImGui

    render_source = joinpath(pathof(CImGui), "..", "..", "examples", "Renderer.jl")
    @show render_source
    include(render_source)
    using .Renderer
    using ..MyModels

    
    function drawAgentRect!(draw_list, canvas_pos, canvas_size, aAgent::Agent)

        CImGui.AddRectFilled(draw_list, 
            ImVec2(
                canvas_pos.x + ((aAgent.pos_x - aAgent.size) * canvas_size.x) , 
                canvas_pos.y + ((aAgent.pos_y - aAgent.size) * canvas_size.y)
            ), 
            ImVec2(
                canvas_pos.x + ((aAgent.pos_x + aAgent.size ) * canvas_size.x) , 
                canvas_pos.y + ((aAgent.pos_y + aAgent.size ) * canvas_size.y)+ aAgent.size
            ), 
            IM_COL32(0, 255, 255, 255)
            )
    end

    """get ratio of value between min and max"""
    function scale_to_norm(value, min, max )
        if value< min
            return min
        end
        if value > max
            return max
        end
        width = max - min
        x = value - min
        return x/width
    end

    function drawAgentCirc!(draw_list, canvas_pos, canvas_size, aAgent::Agent)

        CImGui.AddCircleFilled(draw_list, 
            ImVec2(
                canvas_pos.x + ((aAgent.pos_x) * canvas_size.x) , 
                canvas_pos.y + ((aAgent.pos_y) * canvas_size.y)
            ), 
            canvas_size.x * aAgent.size, 
            aAgent.color, 
            12)
        
        # AddTriangleFilled(handle::Ptr{ImDrawList}, a, b, c, col) = ImDrawList_AddTriangleFilled(handle, a, b, c, col)
        agent_move_x = aAgent.pos_x + sin(aAgent.direction_angle) * aAgent.size
        agent_move_y = aAgent.pos_y + cos(aAgent.direction_angle) * aAgent.size
        agent_move_ort_x = sin(pi/2+aAgent.direction_angle) * (aAgent.size/3)
        agent_move_ort_y = cos(pi/2+aAgent.direction_angle) * (aAgent.size/3)
        agent_move_ort1_x = aAgent.pos_x + agent_move_ort_x
        agent_move_ort1_y = aAgent.pos_y + agent_move_ort_y
        agent_move_ort2_x = aAgent.pos_x - agent_move_ort_x
        agent_move_ort2_y = aAgent.pos_y - agent_move_ort_y
        CImGui.AddTriangleFilled(draw_list,
            ImVec2(
                canvas_pos.x + ((agent_move_x) * canvas_size.x) , 
                canvas_pos.y + ((agent_move_y) * canvas_size.y)
            ),
            ImVec2(
                canvas_pos.x + ((agent_move_ort1_x) * canvas_size.x) , 
                canvas_pos.y + ((agent_move_ort1_y) * canvas_size.y)
            ),
            ImVec2(
                canvas_pos.x + ((agent_move_ort2_x) * canvas_size.x) , 
                canvas_pos.y + ((agent_move_ort2_y) * canvas_size.y) 
            ), 
            IM_COL32(0, floor(255 * scale_to_norm(aAgent.speed,0, 0.05)), 0, 255)
        )

        CImGui.AddCircleFilled(draw_list, 
            ImVec2(
                canvas_pos.x + ((agent_move_x) * canvas_size.x) , 
                canvas_pos.y + ((agent_move_y) * canvas_size.y)
            ), 
            canvas_size.x * aAgent.size / 10, 
            IM_COL32(255, 0,0 , 255), 
            12)

        
    end

    using CImGui: ImVec2, ImVec4, IM_COL32, ImU32

    col=Cfloat[1.0,1.0,0.4,1.0]

    # this is the UI function, whenever the structure of `MyStates` is changed, 
    # the corresponding changes should be applied
    function ui(controlState::ControlState, simState::Ref{SimulationState})
        CImGui.SetNextWindowSize((400, 500), CImGui.ImGuiCond_Once)
        CImGui.Begin("CanvasWindow")
            draw_list = CImGui.GetWindowDrawList()
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
            
            for agent in simState[].last_step[].agent_list
                # drawAgentRect!(draw_list, canvas_pos, canvas_size, agent)
                drawAgentCirc!(draw_list, canvas_pos, canvas_size, agent)
            end
            CImGui.InvisibleButton("canvas", canvas_size) 
            
            CImGui.Separator()
            CImGui.Text(string("Frametime: ", simState[].last_step[].last_frame_time_ms, "ms"))
            
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
        @info "starting render loop..."
        return Renderer.render(()->ui(ctrlState, simState), width = 800, height = 600, title = "A simple UI")
    end

end
    
if abspath(PROGRAM_FILE) == @__FILE__
    using .MyGui
    using .MyModels
    using .MyModelExamples
    
    @info "running gui with some dummy-data for debugging..."
    function infinite_loop(state::ControlState)
        state.is_stop = false
        @async while true
            state.is_stop && break
            push!(state.arr, popat!(state.arr, 1) * state.afloat)
            yield()
        end
    end

    t_render = start_render_loop!(ctrlState, Ref(simState))
    @info "starting dummy update loop..."
    t_update = infinite_loop(ctrlState)
    !isinteractive() && wait(t_render)
    #!isinteractive() && wait(t_update)
    @info "starting dummy update loop...done"
end