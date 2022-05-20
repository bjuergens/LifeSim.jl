

module LSLin
    export Vec2
    export wrap, clip, ratio_to_intverall, interval_to_ratio
    export angle_to_axis, move_in_direction, direction, distance, stretch_to_length
    export Ɛ
    export angle_to_y_axis

    # using LinearAlgebra
    using StaticArrays
    using Distances: Euclidean
    
    const dist_euclid = Euclidean() # initiate one instance at compiletime for faster speed, maybe
    const Ɛ =  1e-15

    "position in simulation-space"
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
        # explicitly unfolding seems to be faster than using implicit elementwise, maybe
        return Vec2(wrap(value.x, start.x, width.x),
                    wrap(value.y, start.y, width.y))
    end

    "if value is outside interval, set to border"
    function clip(value::Number, start::Number, width::Number)
        value = max(start, value)
        value = min(start+width, value)
        return value
    end

    "linear mapping from some interval to [0,1]. Enforces boundaries"
    function ratio_to_intverall(value::Number, start::Number, width::Number)
        value = clamp(value, 0.0, 1.0)
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

    "return angle between vector and y-axis"
    function angle_to_y_axis(p::Vec2)
        if -Ɛ < p.x < Ɛ && -Ɛ < p.y < Ɛ
            @debug "input" p Ɛ
            @debug "atan not defined for 0 values" stacktrace()[3:end]
        end
        return atan(p.x,p.y)
    end
    "return angle between vector and x-axis"
    function angle_to_axis(p::Vec2)
        if -Ɛ < p.x < Ɛ && -Ɛ < p.y < Ɛ
            @debug "input" p Ɛ
            @debug "atan not defined for 0 values" stacktrace()[3:end]
        end
        return atan(p.y,p.x)
    end

    "return angle between 2 points, where x-axis is 0 and y-axis is pi/2"
    function direction(p1::Vec2, p2::Vec2)
        return angle_to_axis(p2-p1)
    end

    "move point1 in the direction by distance"
    function move_in_direction(p::Vec2, direction::Number, distance::Number)
        return Vec2( p.x + cos(direction) * distance,
                     p.y + sin(direction) * distance)
    end

    "Euclidean distance between two points"
    function distance(p1::Vec2, p2::Vec2)
        return dist_euclid((p1.x,p1.y), (p2.x,p2.y))
    end

    "Euclidean distance from point to origin"
    function distance(p1::Vec2)
        return dist_euclid((p1.x,p1.y), Vec2(0,0))
    end

    "stretches a vector so its norm becomes target_length"
    function stretch_to_length(p::Vec2, target_length::Number)
        old_length = distance(p)
        ratio = target_length/old_length
        return p*ratio
    end

end #module 


module LinTests
export doTest
using Test
using Test
using ..LSLin


function distance_manual(p::Vec2)
    return sqrt(p.x^2 + p.y^2)
end
function distance_manual(p1::Vec2, p2::Vec2)
    return distance_manual(p2-p1)
end


macro test_distance(p1, p2, atol=0.0)
    return :( @test distance_manual($p1,$p2) ≈ distance($p1,$p2)  atol=$atol )
end

function doTest()
@testset "Examples" begin

    @test 1+1==2  # canary
    @test Ɛ > 0
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
    
    # test Vec2: constructor, similarity and tolerance
    @test Vec2(0.01,0.01) ≈ Vec2(0.,0.) atol=0.02
    @test Vec2(0.01,0.01) ≉ Vec2(0.,0.) atol=0.002

    # free stuff gained from using StaticArrays
    @test Vec2(1.0,1.0) + Vec2(1.0,1.0) ≈ Vec2(2.0,2.0)
    @test Vec2(1.0,1.0) * 2.0 ≈ Vec2(2.0,2.0)
    @test sin.(Vec2(pi,pi))  ≈ Vec2(0,0) atol=1e-15
    @test sin.(0.5*Vec2(pi,pi))  ≈ Vec2(1,1) atol=1e-15

    # full circle is 2pi, and it start at x-axis and increases counter clockwise
    @test angle_to_axis(Vec2(1., 0.))  ≈ 0
    @test angle_to_axis(Vec2(0., 1.))  ≈ pi/2
    @test angle_to_axis(Vec2(-1., 0.)) ≈ pi
    @test angle_to_axis(Vec2(0., -1.)) ≈ -pi/2

    # direction from point that is right/left of another point
    @test direction(Vec2(0,0), Vec2(1,0))   ≈ 0
    @test direction(Vec2(12,3), Vec2(13,3)) ≈ 0
    @test direction(Vec2(1,0), Vec2(0,0))   ≈ pi
    @test direction(Vec2(13,3), Vec2(12,3)) ≈ pi
    # @test direction(Vec2(0,0), Vec2(0,0)) ≈ 0 # skip because clutter on console

    CENTER = Vec2(0.5, 0.5)
    pos =Vec2(0.6, 0.5)
    @test direction(pos, CENTER) ≈ pi
    @test direction(Vec2(0.6,0.5), Vec2(0.5,0.5)) ≈ pi

    # value in opposite directions should be inverse of each other (within 2pi)
    @test direction(Vec2(0,0), Vec2(1,0)) ≈ direction(Vec2(1,0), Vec2(0,0) ) + pi  - 2pi
    @test direction(Vec2(1,1), Vec2(1,0)) ≈ direction(Vec2(1,0), Vec2(1,1) ) + pi  - 2pi
    @test direction(Vec2(123,213), Vec2(456,567)) ≈ direction(Vec2(456,567),Vec2(123,213) ) + pi

    # move along axes
    @test move_in_direction(Vec2(1., 0.), pi/2, 1.) ≈ Vec2(1.,1.)
    @test move_in_direction(Vec2(1., 0.), pi  , 1.) ≈ Vec2(0.,0.) atol=Ɛ

    # move 90° from origin
    @test move_in_direction(Vec2(0,0), 0.5pi, 1.) ≈ Vec2( 0., 1.)
    @test move_in_direction(Vec2(0,0), 1.0pi, 1.) ≈ Vec2(-1., 0.)
    @test move_in_direction(Vec2(0,0), 1.5pi, 1.) ≈ Vec2( 0.,-1.)
    @test move_in_direction(Vec2(0,0), 2.0pi, 1.) ≈ Vec2( 1., 0.)
    # different notation
    @test move_in_direction(Vec2(0,0), pi/2, 1.) ≈ Vec2(0.,1.)
    @test move_in_direction(Vec2(0,0), 3pi/2, 1.) ≈ Vec2(0., -1.)
    
    # move 45˚ on unit grid
    @test move_in_direction(Vec2(3,3),   pi/4, sqrt(2)) ≈ Vec2(4.,4.)
    @test move_in_direction(Vec2(3,3),  -pi/4, sqrt(2)) ≈ Vec2(4.,2.)
    @test move_in_direction(Vec2(3,3),  3pi/4, sqrt(2)) ≈ Vec2(2.,4.)
    @test move_in_direction(Vec2(3,3), -3pi/4, sqrt(2)) ≈ Vec2(2.,2.)

    # should wrap around
    @test move_in_direction(Vec2(3,3), -3pi/4, sqrt(2)) ≈ move_in_direction(Vec2(3,3), -3pi/4 + 2pi, sqrt(2)) 

    # test some simple distance 
    @test distance(Vec2(0,0),     Vec2(  1,  0)) ≈ 1
    @test distance(Vec2(0,0),     Vec2(  3,  4)) ≈ 5
    @test distance(Vec2(-10,-10), Vec2(-13,-14)) ≈ 5
    @test distance(Vec2(0,0),     Vec2( -3, -4)) ≈ 5

    # rudimentary test on test-method
    @test distance_manual(Vec2(1,1), Vec2(1,2)) ≈ 1
    @test distance_manual(Vec2(1,1), Vec2(1,0)) ≈ 1
    @test distance_manual(Vec2(0,0), Vec2(1,1)) ≈ sqrt(2)
    @test distance_manual(Vec2(0,0), Vec2(2,2)) ≈ sqrt(8)

    # compare fast euclidean from module with simple test-version
    @test_distance Vec2(  0,  0) Vec2(1,0)
    @test_distance Vec2(  1,  1) Vec2(1,0) 
    @test_distance Vec2( -2,  0) Vec2(2,0)
    @test_distance Vec2( 12,-23) Vec2(-34,45)   
    @test_distance Vec2(-12,-23) Vec2(-34,-45)    

    # test for 1d distance
    @test distance(Vec2(  0, 0)) ≈ 0
    @test distance(Vec2(-11, 0)) ≈ 11
    @test distance(Vec2(-11,11)) ≈ sqrt(2*11*11)

    # move one point in the direction of another point by their distance, then they should end up on the same spot
    @test move_in_direction(Vec2(0.0,0.0), angle_to_axis(Vec2(3.0,4.0)), 5.0)  ≈ Vec2(3.0,4.0) atol=0.00001 
    p1 = Vec2(12,23)
    p2 = Vec2(34,45)
    @test move_in_direction(p1, direction(p1,p2), distance(p1,p2)) ≈ p2 

    # stretch along axis
    @test stretch_to_length(Vec2( 1, 0), 5) ≈ Vec2(5,0)
    @test stretch_to_length(Vec2( 0, 1), 5) ≈ Vec2(0,5)
    @test stretch_to_length(Vec2(-1, 0), 5) ≈ Vec2(-5,0)
    @test stretch_to_length(Vec2( 0,-1), 5) ≈ Vec2(0,-5)
    @test stretch_to_length(Vec2( 1, 1), distance(Vec2(5,5))) ≈ Vec2(5,5)
    @test stretch_to_length(Vec2(-1,-1), distance(Vec2(5,5))) ≈ Vec2(-5,-5)

    # move in negativ direction
    @test stretch_to_length(Vec2( 1, 1), -distance(Vec2(5,5))) ≈ Vec2(-5,-5)

    # stretching to anything and then stretching to original length will recreate the original input
    @test stretch_to_length(stretch_to_length(Vec2(-3,4), 5), distance(Vec2(-3,4))) ≈ Vec2(-3,4)

    function myStackOverflowError()
        # https://github.com/JuliaArrays/StaticArrays.jl/issues/1026
        f32::Float32 = 1.0
        f64::Float64 = 1.0
        pos = Vec2(f32, f64)
        return true
    end

    # dont even run with broken, because it takes a little longer
    # @test myStackOverflowError() broken=true  

end
end
end #module LinTests

if abspath(PROGRAM_FILE) == @__FILE__
    ENV["JULIA_DEBUG"]="lin"
    using .LinTests
    doTest()
end
