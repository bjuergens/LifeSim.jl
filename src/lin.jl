

module LSLin
    export Vec2
    export wrap, clip, ratio_to_intverall, interval_to_ratio
    export angle_to_axis

    # using Math

    Vec2 = @NamedTuple{x::Cfloat,y::Cfloat}

    "if value is outside interval, wrap once"
    function wrap(value, min, width)
        value = value>min+width ? value-width : value
        value = value<min ? value+width : value
        return value
    end

    "if value is outside interval, set to border"
    function clip(value, min, width)
        
        if value > min+width
            return  min+width
        end

        if value < min
            return min
        end
        return value
    end

    "linear mapping from some interval to [0,1]. Enforces boundaries"
    function ratio_to_intverall(value, min, width )
        if value< 0.0
            return min
        end
        if value > 1.0
            return min + width
        end
        return min + (value * width)
    end

    "linear mapping from [0,1] to some other interval. Enforces boundaries"
    function interval_to_ratio(value, min, width )
        if value< min
            return min
        end
        if value > min+width
            return min+width
        end
        x = value - min
        return x/width
    end

    function angle_to_axis(p::Vec2)
        return atan(p.x,p.y)
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

    xAxis::Vec2 = (x=0., y=1.)
    yAxis::Vec2 = (x=1., y=0.)
    @test angle_to_axis(xAxis)  ≈ 0
    @test angle_to_axis(yAxis)  ≈ pi/2
end
end
end #module LinTests

if abspath(PROGRAM_FILE) == @__FILE__
    using .LinTests
    doTest()
end
