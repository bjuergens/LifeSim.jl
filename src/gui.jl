

if abspath(PROGRAM_FILE) == @__FILE__
    include("models.jl") 
end

module MyGui
    export start_render_loop!
    using CImGui
    render_source = joinpath(pathof(CImGui), "..", "..", "examples", "Renderer.jl")
    @show render_source
    include(render_source)
    using .Renderer:init_renderer
    using .Renderer:renderloop
    using ..MyModels

    # move to new pacakge for linalg
    "linear mapping from some interval to [0,1]. Enforces boundaries"
    function ratio_to_intverall(value, min, width )
        if value< min
            return min
        end
        if value > min+width
            return min+width
        end
        x = value - min
        return x/width
    end

    "linear mapping from [0,1] to some other interval. Enforces boundaries"
    function interval_to_ratio(value, min, width )
        if value< 0.0
            return min
        end
        if value > 1.0
            return max
        end
        return min + (value * width)
    end

    "map a point in sim space = [0,1]^2 to a point in pixelspace, which integer relativ to window"
    function sim_to_pixel_point(sim_pos::Vec2, pixel_base, pixel_width)
        return ImVec2(
            interval_to_ratio(sim_pos.x, pixel_base.x, pixel_width.x) , 
            interval_to_ratio(sim_pos.y, pixel_base.y, pixel_width.y))
    end

    function drawAgentCirc!(draw_list, canvas_pos, canvas_size, aAgent::Agent)
        
        CImGui.AddCircleFilled(draw_list, 
            sim_to_pixel_point(aAgent.pos, canvas_pos, canvas_size), 
            canvas_size.x * aAgent.size, 
            aAgent.color, 
            12)
        
        agent_move = (x= aAgent.pos.x + sin(aAgent.direction_angle) * aAgent.size,
                      y= aAgent.pos.y + cos(aAgent.direction_angle) * aAgent.size)
        agent_move_ort = (x= sin(pi/2+aAgent.direction_angle) * (aAgent.size/3),
                          y= cos(pi/2+aAgent.direction_angle) * (aAgent.size/3))
        agent_move_ort1 = (x= convert(Cfloat, aAgent.pos.x + agent_move_ort.x),
                           y= convert(Cfloat, aAgent.pos.y + agent_move_ort.y))
        agent_move_ort2 = (x= convert(Cfloat, aAgent.pos.x - agent_move_ort.x),
                           y= convert(Cfloat, aAgent.pos.y - agent_move_ort.y))
        CImGui.AddTriangleFilled(draw_list,
            sim_to_pixel_point(agent_move,canvas_pos, canvas_size),
            sim_to_pixel_point(agent_move_ort1,canvas_pos, canvas_size),
            sim_to_pixel_point(agent_move_ort2,canvas_pos, canvas_size),
            IM_COL32(0, floor(255 * ratio_to_intverall(aAgent.speed,0, 0.05)), 0, 255)
        )

        CImGui.AddCircleFilled(draw_list, 
            sim_to_pixel_point(agent_move,canvas_pos, canvas_size), 
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
            
            for agent in simState[].last_step[].agent_list
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
        window, ctx = init_renderer(800, 600, "blubb")
        GC.@preserve window ctx begin
            t = @async renderloop(window, ctx,  ()->ui(ctrlState, simState), false)
        end
        return t
    end
end



module GuiTests
# Testing-module is needed as workaround for error "ERROR: LoadError: UndefVarError: @safetestset not defined"
# when macro is called in toplevel-block that is not a module.
using SafeTestsets
export doTest
function doTest()
@safetestset "Examples" begin
    using ...MyGui
    using ...MyModelExamples
    
    @test 0<aAgent.pos.x<1
    @test 1+1==2  # canary
end
end
end #module GuiTests

if abspath(PROGRAM_FILE) == @__FILE__
end

    
if abspath(PROGRAM_FILE) == @__FILE__
    using .MyGui
    using .MyModels
    using .MyModelExamples
    using .GuiTests
    doTest()
    
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