

if abspath(PROGRAM_FILE) == @__FILE__
    include("lin.jl")
    include("models.jl") 
end

module LSGui
    export start_render_loop!
    using Revise
    using CImGui
    render_source = joinpath(pathof(CImGui), "..", "..", "examples", "Renderer.jl")
    @show render_source
    include(render_source)
    using .Renderer:init_renderer
    using .Renderer:renderloop
    using ..LSModels
    using ..LSLin
    using CImGui: ImVec2, ImVec4, IM_COL32, ImU32

    using CImGui.CSyntax.CStatic
    using Printf

    "internal state of gui"
    mutable struct GuiState
        show_app_metrics::Bool
        show_overlay_input::Ref{Bool}
    end

    "map a point in sim space = [0,1]^2 to a point in pixelspace, which integer relativ to window"
    function sim_to_pixel_point(sim_pos::Vec2, pixel_base::CImGui.LibCImGui.ImVec2, pixel_width::CImGui.LibCImGui.ImVec2)
        return ImVec2(ratio_to_intverall(sim_pos.x, pixel_base.x, pixel_width.x),
        ratio_to_intverall(sim_pos.y, pixel_base.y, pixel_width.y))
    end

    function drawAgentCirc!(draw_list, canvas_pos, canvas_size, aAgent::Agent)
        
        CImGui.AddCircleFilled(draw_list, 
            sim_to_pixel_point(aAgent.pos, canvas_pos, canvas_size), 
            canvas_size.x * aAgent.size, 
            aAgent.color, 
            12)
        # todo: use LSLin here
        agent_move = Vec2( aAgent.pos.x + cos(aAgent.direction_angle) * aAgent.size,
                           aAgent.pos.y + sin(aAgent.direction_angle) * aAgent.size)
        agent_move_ort = Vec2( cos(pi/2+aAgent.direction_angle) * (aAgent.size/3),
                               sin(pi/2+aAgent.direction_angle) * (aAgent.size/3))
        agent_move_ort1 = Vec2( convert(Cfloat, aAgent.pos.x + agent_move_ort.x),
                                convert(Cfloat, aAgent.pos.y + agent_move_ort.y))
        agent_move_ort2 = Vec2(convert(Cfloat, aAgent.pos.x - agent_move_ort.x),
                               convert(Cfloat, aAgent.pos.y - agent_move_ort.y))

        CImGui.AddTriangleFilled(draw_list,
            sim_to_pixel_point(agent_move,canvas_pos, canvas_size),
            sim_to_pixel_point(agent_move_ort1,canvas_pos, canvas_size),
            sim_to_pixel_point(agent_move_ort2,canvas_pos, canvas_size),
            IM_COL32(0, floor(255 * interval_to_ratio(aAgent.speed,0, 0.05)), 0, 255)
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
            CImGui.Text(string("Frametime: ", simState[].last_step[].last_frame_time_ms, "ms"))
            
            min_frametime_ms = Ref(controlState[].min_frametime_ms)
            CImGui.SliderFloat("min_frame_time", min_frametime_ms, 0.0, 100.0, "time = %.3f ms")
            controlState[].min_frametime_ms = min_frametime_ms[]

        CImGui.End()
    end

    function showWindowOptions!(guiState::Ref{GuiState}, controlState::Ref{ControlState})
        show_app_metrics = Ref(guiState[].show_app_metrics)
        show_overlay_input = guiState[].show_overlay_input
        window_flags_options = CImGui.ImGuiWindowFlags(0)
        window_flags_options |= CImGui.ImGuiWindowFlags_MenuBar
        
        CImGui.SetNextWindowSize((300, 400), CImGui.ImGuiCond_Once)

        CImGui.Begin("OptionsWindow", Ref(true), window_flags_options)
            
            if CImGui.BeginMenuBar()
                if CImGui.BeginMenu("Help")
                    CImGui.MenuItem("Metrics", C_NULL, show_app_metrics)
                    CImGui.MenuItem("InputInfo", C_NULL, guiState[].show_overlay_input)
                    CImGui.EndMenu()
                end
                CImGui.EndMenuBar()
            end
            
            is_connected = Ref(controlState[].is_stop)
            float_ref = Ref(controlState[].afloat)
            CImGui.SliderFloat("slider float", float_ref, 0.0, 2.0, "ratio = %.3f")
            controlState[].afloat = float_ref[]

            if CImGui.Checkbox("connected?", is_connected)
                controlState[].is_stop = !is_connected[]
            end
            CImGui.PlotLines("sine wave", controlState[].arr, length(controlState[].arr))

            CImGui.Separator()
            CImGui.Button("REVISE") && begin 
                @info "revise..."
                revise()
                controlState[].request_revise += 1
                @info "revise... done"
            end
            CImGui.Separator()
        CImGui.End()

        guiState[].show_app_metrics = show_app_metrics[]
    end

    function showWindowMetrics!(guiState::Ref{GuiState})
        show_app_metrics = Ref(guiState[].show_app_metrics)
        show_app_metrics[] && CImGui.ShowMetricsWindow(show_app_metrics)
        guiState[].show_app_metrics = show_app_metrics[]
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



    # this is the UI function, whenever the structure of `MyStates` is changed, 
    # the corresponding changes should be applied
    function ui(controlState::Ref{ControlState}, simState::Ref{SimulationState}, guiState::Ref{GuiState})

        showWindowSimulationView(controlState, simState)
        showWindowOptions!(guiState, controlState)
        showWindowMetrics!(guiState)

        guiState[].show_overlay_input[] && ShowOverlayInput!(guiState[].show_overlay_input)
    end

    function start_render_loop!(ctrlState::Ref{ControlState}, simState::Ref{SimulationState}, hotreload=false)
        @info "starting render loop..."
        window, ctx = init_renderer(800, 600, "LifeSim.jl")
        gui_state = Ref(GuiState(true, Ref(true)))
        GC.@preserve window ctx begin
                t = @async renderloop(window, ctx,  ()->ui(ctrlState, simState, gui_state), hotreload)
        end
        return t, window
    end
end



module GuiTests
# Testing-module is needed as workaround for error "ERROR: LoadError: UndefVarError: @safetestset not defined"
# when macro is called in toplevel-block that is not a module.
using Test
using ..LSGui
using ..LSModelExamples
using GLFW
export doTest
function doTest()
@testset "Examples" begin
    
    function render_win_for_half_second()
        _, window = start_render_loop!(Ref(ctrlState), Ref(simState))
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

    keep_open = false
    if keep_open
        t_render, _ = start_render_loop!(ctrlState, Ref(simState))
        t_update = infinite_loop(ctrlState)
        !isinteractive() && wait(t_render)
    end
end