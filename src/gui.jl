

if abspath(PROGRAM_FILE) == @__FILE__
    include("lin.jl")
    include("models.jl") 
    include("simulation.jl")
end

module LSGui
    export LS_render_loop! # LS-prefix to avoid namecollision
    export GuiState
    using Revise
    using CImGui
    render_source = joinpath(pathof(CImGui), "..", "..", "examples", "Renderer.jl")
    @show render_source
    include(render_source)
    using .Renderer:init_renderer
    using .Renderer:renderloop
    using ..LSModels
    using ..LSLin
    using ..LSSimulation:makeSensorInput
    using CImGui: ImVec2, ImVec4, IM_COL32, ImU32

    using CImGui.CSyntax.CStatic
    using Printf
    using Flatten


    "internal state of gui"
    mutable struct GuiState
        show_app_metrics::Ref{Bool}
        show_overlay_input::Ref{Bool}
        show_window_pop_list::Ref{Bool}
        history_frametime::Vector{Cfloat}
        history_num_agents::Vector{Cfloat}
        GuiState(; show_app_metrics=true, show_overlay_input=true, show_window_pop_list, history_frametime=zeros(Cfloat, 100)) = 
           new(Ref(show_app_metrics), Ref(show_overlay_input), Ref(show_window_pop_list),history_frametime)
        GuiState(open_all) =  new(open_all, Ref(open_all), Ref(open_all), zeros(Cfloat, 100), zeros(Cfloat, 100))
    end

    "map a point in sim space = [0,1]^2 to a point in pixelspace, which integer relativ to window"
    function sim_to_pixel_point(sim_pos::Vec2, pixel_base::CImGui.LibCImGui.ImVec2, pixel_width::CImGui.LibCImGui.ImVec2)
        return ImVec2(ratio_to_intverall(sim_pos.x, pixel_base.x, pixel_width.x),
        ratio_to_intverall(sim_pos.y, pixel_base.y, pixel_width.y))
    end

    function drawAgentCirc!(draw_list, canvas_pos, canvas_size, aAgent::Agent)
        
        # todo: draw sensordata
        sensor = makeSensorInput(aAgent)

        #sleep(100)
        #@show sensor
        #sleep(100)

        CImGui.AddCircleFilled(draw_list, 
            sim_to_pixel_point(aAgent.pos, canvas_pos, canvas_size), 
            canvas_size.x * aAgent.size, 
            aAgent.color, 
            12)

        agent_move      = move_in_direction(aAgent.pos, aAgent.direction_angle,      aAgent.size)
        agent_move_ort1 = move_in_direction(aAgent.pos, aAgent.direction_angle-pi/2, aAgent.size/3)
        agent_move_ort2 = move_in_direction(aAgent.pos, aAgent.direction_angle+pi/2, aAgent.size/3)

        CImGui.AddTriangleFilled(draw_list,
            sim_to_pixel_point(agent_move,canvas_pos, canvas_size),
            sim_to_pixel_point(agent_move_ort1,canvas_pos, canvas_size),
            sim_to_pixel_point(agent_move_ort2,canvas_pos, canvas_size),
            IM_COL32(0, floor(255 * interval_to_ratio(aAgent.speed,0, 0.05)), 0, 255)
        )

        compass_main = move_in_direction(aAgent.pos, aAgent.direction_angle - sensor.compass_center,      aAgent.size)
        compass_ort1 = move_in_direction(aAgent.pos, aAgent.direction_angle - sensor.compass_center-pi/2, aAgent.size/8)
        compass_ort2 = move_in_direction(aAgent.pos, aAgent.direction_angle - sensor.compass_center+pi/2, aAgent.size/8)

        CImGui.AddTriangleFilled(draw_list,
            sim_to_pixel_point(compass_main,canvas_pos, canvas_size),
            sim_to_pixel_point(compass_ort1,canvas_pos, canvas_size),
            sim_to_pixel_point(compass_ort2,canvas_pos, canvas_size),
            IM_COL32(255, 255, 255, 50)
        )
        compass2_main = move_in_direction(aAgent.pos, aAgent.direction_angle-sensor.compass_north,      aAgent.size)
        compass2_ort1 = move_in_direction(aAgent.pos, aAgent.direction_angle-sensor.compass_north-pi/2, aAgent.size/8)
        compass2_ort2 = move_in_direction(aAgent.pos, aAgent.direction_angle-sensor.compass_north+pi/2, aAgent.size/8)

        CImGui.AddTriangleFilled(draw_list,
            sim_to_pixel_point(compass2_main,canvas_pos, canvas_size),
            sim_to_pixel_point(compass2_ort1,canvas_pos, canvas_size),
            sim_to_pixel_point(compass2_ort2,canvas_pos, canvas_size),
            IM_COL32(0, 255, 255, 50)
        )


        CImGui.AddCircleFilled(draw_list, 
            sim_to_pixel_point(agent_move,canvas_pos, canvas_size), 
            canvas_size.x * aAgent.size / 10, 
            IM_COL32(255, 0 ,0 , 255), 
            12)

       
    end

    function showWindowSimulationView(controlState::Ref{ControlState}, simState::Ref{SimulationState})
        CImGui.SetNextWindowSize((400, 500), CImGui.ImGuiCond_Once)
        CImGui.Begin("SimulationView")
            draw_list = CImGui.GetWindowDrawList()
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
            
            for agent in simState[].last_step[].agent_list
                drawAgentCirc!(draw_list, canvas_pos, canvas_size, agent)
            end
            CImGui.InvisibleButton("canvas", canvas_size) 
            
            CImGui.Separator()
            frametime = simState[].last_step[].last_frame_time_ms
            CImGui.Text(string( @sprintf( "Frametime: %07.3f ms / %09.2f fps", frametime, 1000/frametime)))
            
            min_frametime_ms = Ref(controlState[].min_frametime_ms)
            CImGui.SliderFloat("min_frame_time", min_frametime_ms, 0.0, 100.0, "time = %.3f ms")
            controlState[].min_frametime_ms = min_frametime_ms[]

        CImGui.End()
    end

    function showWindowOptions!(guiState::Ref{GuiState}, controlState::Ref{ControlState})
        window_flags_options = CImGui.ImGuiWindowFlags(0)
        window_flags_options |= CImGui.ImGuiWindowFlags_MenuBar
        
        CImGui.SetNextWindowSize((300, 400), CImGui.ImGuiCond_Once)

        CImGui.Begin("OptionsWindow", Ref(true), window_flags_options)
            
            if CImGui.BeginMenuBar()
                if CImGui.BeginMenu("Help")
                    CImGui.MenuItem("Metrics", C_NULL, guiState[].show_app_metrics)
                    CImGui.MenuItem("InputInfo", C_NULL, guiState[].show_overlay_input)
                    CImGui.EndMenu()
                end
                CImGui.EndMenuBar()
            end
            
            is_connected = Ref(controlState[].is_stop)

            if CImGui.Checkbox("connected?", is_connected)
                controlState[].is_stop = !is_connected[]
            end
            #PlotLines(label, values, values_count, values_offset=0, overlay_text=C_NULL, scale_min=FLT_MAX, scale_max=FLT_MAX, graph_size=ImVec2(0,0), stride=sizeof(Cfloat))
            CImGui.PlotLines("frametimes", guiState[].history_frametime, length(guiState[].history_frametime),  0, "", 0,CImGui.FLT_MAX,ImVec2(200,50))
            CImGui.PlotLines("num agents", guiState[].history_num_agents, length(guiState[].history_num_agents),0, "", 0,CImGui.FLT_MAX,ImVec2(200,50))


            CImGui.Separator()
            CImGui.Button("REVISE") && begin 
                @info "doing revise on gui"
                revise()
                @info "send revise request"
                controlState[].request_revise += 1
            end
            CImGui.Button("PAUSE") && begin 
                @info "send request_pause"
                controlState[].request_pause += 1
            end
            CImGui.Button("PLAY") && begin 
                @info "send request_play"
                controlState[].request_play += 1
            end
            CImGui.Button("add agent") && begin 
                @info "send request_add_agent"
                controlState[].request_add_agent += 1
            end
            CImGui.Separator()

            cull_minimum = Ref(controlState[].cull_minimum)
            CImGui.SliderInt("cull_minimum", cull_minimum, 1, 100)
            controlState[].cull_minimum = cull_minimum[]

            cull_frequency = Ref(controlState[].cull_frequency)
            CImGui.SliderFloat("cull_frequency", cull_frequency, 1, 100)
            controlState[].cull_frequency = cull_frequency[]

            cull_percentage = Ref(controlState[].cull_percentage)
            CImGui.SliderFloat("cull_percentage", cull_percentage, 1, 100)
            controlState[].cull_percentage = cull_percentage[]
        CImGui.End()
    end

    function ShowOverlayInput!(p_open::Ref{Bool})
        DISTANCE = Cfloat(10.0)

        io = CImGui.GetIO()
        @cstatic corner=Cint(0) begin
            if corner != -1
                window_pos_x = corner & 1 != 0 ? io.DisplaySize.x - DISTANCE : DISTANCE
                window_pos_y = corner & 2 != 0 ? io.DisplaySize.y - DISTANCE : DISTANCE
                window_pos = (window_pos_x, window_pos_y)
                window_pos_pivot = (corner & 1 != 0 ? 1.0 : 0.0, corner & 2 != 0 ? 1.0 : 0.0)
                CImGui.SetNextWindowPos(window_pos, CImGui.ImGuiCond_Always, window_pos_pivot)
            end
            CImGui.SetNextWindowBgAlpha(0.3) 
            flag = CImGui.ImGuiWindowFlags_NoTitleBar | CImGui.ImGuiWindowFlags_NoResize |
                CImGui.ImGuiWindowFlags_AlwaysAutoResize | CImGui.ImGuiWindowFlags_NoSavedSettings |
                CImGui.ImGuiWindowFlags_NoFocusOnAppearing | CImGui.ImGuiWindowFlags_NoNav
            flag |= corner != -1 ? CImGui.ImGuiWindowFlags_NoMove : CImGui.ImGuiWindowFlags_None
            if CImGui.Begin("Input Overlay", p_open, flag)
                if CImGui.IsMousePosValid()
                    # for possible values see http://docs.ros.org/en/kinetic/api/lib
                    CImGui.Text(@sprintf("Mouse Position: (%06.1f,%06.1f)", io.MousePos.x, io.MousePos.y))
                    CImGui.Text(@sprintf("Mouse Delta   : (%06.1f,%06.1f)", io.MouseDelta.x, io.MouseDelta.y))
                    CImGui.Separator()
                    CImGui.Text(         "KeyCtrl       : " * ( io.KeyCtrl ? "true" : "false"))
                    CImGui.Text(         "KeyShift      : " * ( io.KeyShift ? "true" : "false"))
                    CImGui.Text(         "KeyAlt        : " * ( io.KeyAlt ? "true" : "false"))
                    CImGui.Text(         "KeySuper      : " * ( io.KeySuper ? "true" : "false"))
                else
                    CImGui.Text("Mouse Position: <invalid>")
                end
                if CImGui.BeginPopupContextWindow()
                    CImGui.MenuItem("Custom",       C_NULL, corner == -1) && (corner = -1;)
                    CImGui.MenuItem("Top-left",     C_NULL, corner == 0) && (corner = 0;)
                    CImGui.MenuItem("Top-right",    C_NULL, corner == 1) && (corner = 1;)
                    CImGui.MenuItem("Bottom-left",  C_NULL, corner == 2) && (corner = 2;)
                    CImGui.MenuItem("Bottom-right", C_NULL, corner == 3) && (corner = 3;)
                    p_open[] && CImGui.MenuItem("Close") && (p_open[] = false;)
                    CImGui.EndPopup()
                end
            end
            CImGui.End()
        end # @cstatic
    end

    function ShowAgentTree(uid, aAgent)
        prefix = "Agent"
        CImGui.PushID(uid) # use object uid as identifier. most commonly you could also use the object pointer as a base ID.
        CImGui.AlignTextToFramePadding()  # Text and Tree nodes are less high than regular widgets, here we add vertical spacing to make the tree lines equal high.
        node_open = CImGui.TreeNode("Object", "Agent #$(uid)")
        CImGui.NextColumn()
        CImGui.AlignTextToFramePadding()
        CImGui.Text("= = = = = = = =  ")
        CImGui.NextColumn()
        agent_fields = fieldnameflatten(aAgent)
        agent_values = flatten(aAgent)
        # @show flatten(aAgent)

        field_id = 1
        if node_open
            for (field,value) in zip(agent_fields,agent_values)
                #@show field , value
                CImGui.PushID(field_id)
                CImGui.AlignTextToFramePadding()
                flag = CImGui.ImGuiTreeNodeFlags_Leaf | CImGui.ImGuiTreeNodeFlags_NoTreePushOnOpen | CImGui.ImGuiTreeNodeFlags_Bullet
                CImGui.TreeNodeEx("Fieldtest123", flag, string(field))

                CImGui.NextColumn()
                CImGui.PushItemWidth(-1)
                
                CImGui.Text("value: " * string(value))

                CImGui.PopItemWidth()
                CImGui.NextColumn()
                CImGui.PopID()
                field_id+=1
            end
            CImGui.TreePop()
        end
        CImGui.PopID()
    end
    
    function ShowwindowPopulationList(simState::Ref{SimulationState}, p_open::Ref{Bool})
        CImGui.SetNextWindowSize((430,450), CImGui.ImGuiCond_FirstUseEver)
        CImGui.Begin("Agent List", p_open) || (CImGui.End(); return)

        CImGui.PushStyleVar(CImGui.ImGuiStyleVar_FramePadding, (2,2))
        CImGui.Columns(2)
        CImGui.Separator()
        # ShowHelpMarker("This example shows how you may implement a property editor using two columns.\nAll objects/fields data are dummies here.\nRemember that in many simple cases, you can use CImGui.SameLine(xxx) to position\nyour cursor horizontally instead of using the Columns() API.");

        tree_id = 1
        for agent in simState[].last_step[].agent_list
            ShowAgentTree(tree_id,agent)
            tree_id += 1
        end

        CImGui.Columns(1)
        CImGui.Separator()
        CImGui.PopStyleVar()
        CImGui.End()
    end # ShowwindowPopulationList


    # this is the UI function, whenever the structure of `MyStates` is changed, 
    # the corresponding changes should be applied
    function ui(controlState::Ref{ControlState}, simState::Ref{SimulationState}, guiState::Ref{GuiState})

        insert!(guiState[].history_frametime, 1,  simState[].last_step[].last_frame_time_ms)
        if length(guiState[].history_frametime)> 300
            pop!(guiState[].history_frametime)
        end
        insert!(guiState[].history_num_agents, 1,  length(simState[].last_step[].agent_list))
        if length(guiState[].history_num_agents)> 300
            pop!(guiState[].history_num_agents)
        end

        showWindowSimulationView(controlState, simState)
        showWindowOptions!(guiState, controlState)
        ShowwindowPopulationList(simState, guiState[].show_window_pop_list)

        guiState[].show_app_metrics[] && CImGui.ShowMetricsWindow(guiState[].show_app_metrics)
        guiState[].show_overlay_input[] && ShowOverlayInput!(guiState[].show_overlay_input)
    end

    # LS-prefix to avoid namecollision
    function LS_render_loop!(ctrlState::Ref{ControlState}, simState::Ref{SimulationState}, guiState::Ref{GuiState}, hotreload=false )
        @info "starting render loop..."
        window, ctx = init_renderer(800, 600, "LifeSim.jl")
        GC.@preserve window ctx begin
                t = @async renderloop(window, ctx,  ()->ui(ctrlState, simState, guiState), hotreload)
        end
        return t, window
    end
end



module GuiTests
# Testing-module is needed as workaround for error "ERROR: LoadError: UndefVarError: @safetestset not defined"
# when macro is called in toplevel-block that is not a module.
using Test
using ..LSGui
using ..LSModels
using ..LSModelExamples
using GLFW
export doTest
function doTest()
@testset "Examples" begin
    
    function render_win_for_half_second()

        _, window = LS_render_loop!(Ref(ControlState()), Ref(simState), Ref(GuiState(true)) )
        sleep(0.5)
        GLFW.SetWindowShouldClose(window, true)
        return true
    end
    @test render_win_for_half_second()
    @test 1+1==2  # canary
end
end
end #module GuiTests

    
if abspath(PROGRAM_FILE) == @__FILE__
    using .LSGui
    using .LSModels
    using .LSModelExamples
    using .GuiTests
    doTest()
end
