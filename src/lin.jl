

module LSLin
    export wrap, limit, ratio_to_intverall, interval_to_ratio

    "if value is outside interval, wrap once"
    function wrap(value, min, width)
        value = value>min+width ? value-width : value
        value = value<min ? value+width : value
        return value
    end

    "if value is outside interval, set to border, and report"
    function limit(value, min, width)
        
        if value > min+width
            return  min+width, false
        end

        if value < min
            return min, false
        end
        return value, true
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
end #module 


module ModelTests
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

    @test limit(-5,-1,2)[1] ≈ -1 
    @test limit(0.3,-1,2)[1] ≈ 0.3
    @test limit(1.3,-1,2)[1] ≈ 1
    
    @test ratio_to_intverall(0.3,0,10)≈3 
    
    @test interval_to_ratio(3, 0, 10)≈0.3
end
end
end #module ModelTests

if abspath(PROGRAM_FILE) == @__FILE__
    using .ModelTests
    doTest()
end
