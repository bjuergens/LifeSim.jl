
using StaticArrays

struct Vec3D{T} <: FieldVector{3, T}
    x::T
    y::T
    z::T
end

@info "this works" Vec3D(1,2,3)
@info "this works" Vec3D(Float32(1), Float32(2),Float32(3))
@info "this works" Vec3D(Float64(1), Float64(2),Float64(3))
@info "this fails" Vec3D(Float32(1), Float32(2),Float64(3))
 