

module LSLin
    export Vec2DTest
    export Vec2
    export wrap, clip, ratio_to_intverall, interval_to_ratio
    export angle_to_axis, move_in_direction, direction, distance
    export direction

    # using LinearAlgebra
    using StaticArrays
    using Distances: Euclidean
    
    const dist_euclid = Euclidean() # initiate one instance at compiletime for faster speed, maybe
    const Ɛ =  1e-15

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

    function write_stack()
        res = []
        for a in stacktrace()
            push!(res, a)
        end
        return res
    end

    "return angle between vector and x-axis"
    function angle_to_axis(p::Vec2)
        if -Ɛ < p.x < Ɛ && -Ɛ < p.y < Ɛ
            @debug "input" p Ɛ
            @debug "atan not defined for 0 values" stacktrace()[3:end]
        end
        return atan(p.x,p.y)
    end

    "return angle between 2 points, where x-axis is 0 and y-axis is pi/2"
    function direction(p1::Vec2, p2::Vec2)
        return angle_to_axis(p2-p1)
    end

    "move point1 in the direction by distance"
    function move_in_direction(p::Vec2, direction::Number, distance::Number)
        return Vec2( p.x + sin(direction) * distance,
                     p.y + cos(direction) * distance)
    end

    "Euclidean distance between two points"
    function distance(p1::Vec2, p2::Vec2)
        return dist_euclid((p1.x,p1.y), (p2.x,p2.y))
    end
    "Euclidean distance from point to origin"
    function distance(p1::Vec2)
        return dist_euclid((p1.x,p1.y), Vec2(0,0))
    end

end #module 


module LinTests
using SafeTestsets
using Test
export doTest
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

    # test Vec2: constructor, similarity and tolerance
    @test Vec2(0.01,0.01) ≈ Vec2(0.,0.) atol=0.02
    @test Vec2(0.01,0.01) ≉ Vec2(0.,0.) atol=0.002

    # free stuff gained from using StaticArrays
    @test Vec2(1.0,1.0) + Vec2(1.0,1.0) ≈ Vec2(2.0,2.0)
    @test Vec2(1.0,1.0) * 2.0 ≈ Vec2(2.0,2.0)
    @test sin.(Vec2(pi,pi))  ≈ Vec2(0,0) atol=1e-15
    @test sin.(0.5*Vec2(pi,pi))  ≈ Vec2(1,1) atol=1e-15

    # move along axes
    @test move_in_direction(xAxis, pi/2, 1.) ≈ Vec2(1.,1.) 
    @test move_in_direction(xAxis, pi, 1.) ≈ Vec2(0.,0.) atol=0.00001

    # move 90° from origin
    @test move_in_direction(Vec2(0,0), 0.5pi, 1.) ≈ Vec2(1.,0.) 
    @test move_in_direction(Vec2(0,0), 1.0pi, 1.) ≈ Vec2(0.,-1.)
    @test move_in_direction(Vec2(0,0), 1.5pi, 1.) ≈ Vec2(-1.,0.)
    @test move_in_direction(Vec2(0,0), 2.0pi, 1.) ≈ Vec2(0.,1.)
    # different notation
    @test move_in_direction(Vec2(0,0), pi/2, 1.) ≈ Vec2(1.,0.) 
    @test move_in_direction(Vec2(0,0), 3pi/2, 1.) ≈ Vec2(-1.,0.)
    
    # move 45˚ on unit grid
    @test move_in_direction(Vec2(3,3), pi/4, sqrt(2)) ≈ Vec2(4.,4.) 
    @test move_in_direction(Vec2(3,3), -pi/4, sqrt(2)) ≈ Vec2(2.,4.) 
    @test move_in_direction(Vec2(3,3), 3pi/4, sqrt(2)) ≈ Vec2(4.,2.) 
    @test move_in_direction(Vec2(3,3), -3pi/4, sqrt(2)) ≈ Vec2(2.,2.) 

    # should wrap around
    @test move_in_direction(Vec2(3,3), -3pi/4, sqrt(2)) ≈ move_in_direction(Vec2(3,3), -3pi/4 + 2pi, sqrt(2)) 

    # test some simple distance 
    @test distance(Vec2(0,0), Vec2(1,0)) ≈ 1
    @test distance(Vec2(0,0), Vec2(3,4)) ≈ 5
    @test distance(Vec2(-10,-10), Vec2(-13,-14)) ≈ 5
    @test distance(Vec2(0,0), Vec2(-3,-4)) ≈ 5

    # rudimentary test on test-method
    @test distance_manual(Vec2(1,1), Vec2(1,2)) ≈ 1
    @test distance_manual(Vec2(1,1), Vec2(1,0)) ≈ 1
    @test distance_manual(Vec2(0,0), Vec2(1,1)) ≈ sqrt(2)
    @test distance_manual(Vec2(0,0), Vec2(2,2)) ≈ sqrt(8)

    # compare fast euclidean from module with simple test-version
    @test_distance Vec2(0,0) Vec2(1,0)
    @test_distance Vec2(1,1) Vec2(1,0) 
    @test_distance Vec2(-2,0) Vec2(2,0)
    @test_distance Vec2(12,-23) Vec2(-34,45)   
    @test_distance Vec2(-12,-23) Vec2(-34,-45)    

    # test for 1d distance
    @test distance(Vec2(0,0)) ≈ 0
    @test distance(Vec2(-11,0)) ≈ 11
    @test distance(Vec2(-11,11)) ≈ sqrt(2*11*11)

    # full circle is 2pi, and it increases counter clockwise
    @test direction(Vec2(0,0), Vec2(1,0))   ≈ pi/2
    @test direction(Vec2(12,3), Vec2(13,3)) ≈ pi/2
    # @test direction(Vec2(0,0), Vec2(0,0)) ≈ 0 # skip because clutter on console
    @test direction(Vec2(0,0), Vec2(1,0)) ≈ pi/2

    # value in opposite directions should be inverse of each other (within 2pi)
    @test direction(Vec2(0,0), Vec2(1,0)) ≈ direction(Vec2(1,0), Vec2(0,0) ) + pi
    @test direction(Vec2(1,1), Vec2(1,0)) ≈ direction(Vec2(1,0), Vec2(1,1) ) + pi
    @test direction(Vec2(123,213), Vec2(456,567)) ≈ direction(Vec2(456,567),Vec2(123,213) ) + pi

    # move one point in the direction of another point by their distance, then the should end up on the same spot
    @test move_in_direction(Vec2(0.0,0.0), angle_to_axis(Vec2(3.0,4.0)), 5.0)  ≈ Vec2(3.0,4.0) atol=0.00001
    p1 = Vec2(12,23)
    p2 = Vec2(34,45)
    @test move_in_direction(p1, direction(p1,p2), distance(p1,p2)) ≈ p2 

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
