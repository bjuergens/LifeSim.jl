

module LSLin
    export Vec2DTest
    export Vec2
    export wrap, clip, ratio_to_intverall, interval_to_ratio
    export angle_to_axis, move_in_direction

    # using LinearAlgebra
    using StaticArrays
    

    struct Vec2{T} <: FieldVector{2, T}
        x::T
        y::T
    end
    StaticArrays.similar_type(::Type{<:Vec2}, ::Type{T}, s::Size{(2,)}) where {T} = Vec2{T}
    

    "if value is outside interval, wrap once"
    function wrap(value::Number, start::Number, width::Number)
        value = value>start+width ? value-width : value
        value = value<start ? value+width : value
        return value
    end

    function wrap(value::Vec2, start::Vec2, width::Vec2)
        return Vec2(wrap(value.x, start.x, width.x),
                    wrap(value.y, start.y, width.y))
    end

    "if value is outside interval, set to border"
    function clip(value::Number, start::Number, width::Number)
        
        if value > start+width
            return  start+width
        end

        if value < start
            return start
        end
        return value
    end

    "linear mapping from some interval to [0,1]. Enforces boundaries"
    function ratio_to_intverall(value::Number, start::Number, width::Number)
        if value< 0.0
            return start
        end
        if value > 1.0
            return start + width
        end
        return start + (value * width)
    end

    "linear mapping from [0,1] to some other interval. Enforces boundaries"
    function interval_to_ratio(value::Number, start::Number, width::Number)
        if value< start
            return start
        end
        if value > start+width
            return start+width
        end
        x = value - start
        return x/width
    end

    function angle_to_axis(p::Vec2)
        return atan(p.x,p.y)
    end

    function move_in_direction(p::Vec2, direction::Number, distance::Number)
        return Vec2( p.x + sin(direction) * distance,
                     p.y + cos(direction) * distance)
    end


end #module 


module LinTests
using SafeTestsets
export doTest
function doTest()
@safetestset "Examples" begin
    using ...LSLin
    @test 1+1==2  # canary
    @test wrap(0.3,0,1) ≈ 0.3
    @test wrap(1.5,0,1) ≈ 0.5
    @test wrap(-0.5,0,1) ≈ 0.5
    @test wrap(1, -pi, 2pi) ≈ 1
    @test wrap(-2pi, -pi, 2pi) ≈ 0

    @test clip(-5,-1,2) ≈ -1 
    @test clip(0.3,-1,2) ≈ 0.3
    @test clip(1.3,-1,2) ≈ 1
    
    @test ratio_to_intverall(0.3,0,10)≈3 
    
    @test interval_to_ratio(3, 0, 10)≈0.3

    xAxis = Vec2(0., 1.)
    yAxis = Vec2(1., 0.)
    @test angle_to_axis(xAxis)  ≈ 0
    @test angle_to_axis(yAxis)  ≈ pi/2

    @test Vec2(0.01,0.01) ≈ Vec2(0.,0.) atol=0.02
    @test Vec2(0.01,0.01) ≉ Vec2(0.,0.) atol=0.002
    @test move_in_direction(xAxis, pi/2, 1.) ≈ Vec2(1.,1.) 
    @test move_in_direction(xAxis, pi, 1.) ≈ Vec2(0.,0.) atol=0.00001

    #@test Vec2(1.0,1.0) + Vec2(1.0,1.0) ≈ Vec2(2.0,2.0)

    # move one point in the direction of another point by their distance, then the should end up on the same spot
    @test move_in_direction(Vec2(0.0,0.0), angle_to_axis(Vec2(3.0,4.0)), 5.0)  ≈ Vec2(3.0,4.0) atol=0.00001


end
end
end #module LinTests

if abspath(PROGRAM_FILE) == @__FILE__
    using .LinTests
    doTest()
end
