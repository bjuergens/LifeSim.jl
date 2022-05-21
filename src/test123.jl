using CollisionDetection
using StaticArrays

function x()
n = 100
centers =  [2 .* rand(SVector{3,Float64}) .- 1 for i in 1:n] 
# center = [randn((SVector){3, Float32}) for in in 1:n]
radii = [0.1*rand() for i in 1:n]

tree = Octree(centers, radii)

# Given an index, is the corresponding ball eligible?
pred(i) = all(centers[i].+radii[i] .> 0)
# Bounding box in the (center,halfside) format supplied for effiency
bb = @SVector[0.5, 0.5, 0.5], 0.5
# collect the iterator of admissible indices
ids = collect(searchtree(pred, tree, bb))
end