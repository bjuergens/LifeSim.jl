

@info "testing stuff"
module testing
using LinearAlgebra
using StaticArrays

export Vec2D, Vec3D

SA[1, 2, 3]     isa SVector{3,Int}
SA_F64[1, 2, 3] isa SVector{3,Float64}
SA_F32[1, 2, 3] isa SVector{3,Float32}
SA[1 2; 3 4]     isa SMatrix{2,2,Int}
SA_F64[1 2; 3 4] isa SMatrix{2,2,Float64}

struct Vec2D{T} <: FieldVector{2, T}
    x::T
    y::T
end

StaticArrays.similar_type(::Type{<:Vec2D}, ::Type{T}, s::Size{(2,)}) where {T} = Vec2D{T}


struct Vec3D{T} <: FieldVector{3, T}
    x::T
    y::T
    z::T
end

StaticArrays.similar_type(::Type{<:Vec3D}, ::Type{T}, s::Size{(3,)}) where {T} = Vec3D{T}

end

using SafeTestsets

@safetestset bla = "blubb" begin

    using ..testing
    using StaticArrays
    
@test Vec3D(1,1,1) == Vec3D(1,1,1)
@test SVector(1, 2, 3) == SVector(1, 2, 3)
@test Vec3D(1,1,1) + Vec3D(1,1,1)==  Vec3D(2,2,2)

@test Vec2D(1,1) == Vec2D(1,1)
@test SVector(1, 2) == SVector(1, 2)
@test Vec2D(1,1) + Vec2D(1,1)==  Vec2D(2,2)

@test 1+1==2 #canary

end