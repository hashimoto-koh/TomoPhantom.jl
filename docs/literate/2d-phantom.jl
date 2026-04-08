# # 2D Phantoms
#
# This tutorial demonstrates how to generate standard benchmark 2D phantoms utilizing `TomoPhantom.jl`. 
# It leverages the globally precomputed phantom library supplied by the core.

using TomoPhantom

# ## Defining the Core and Library Models
# 
# First, we need to instruct Julia to hook into the compiled native C context (`NativeCore`).

core = NativeCore()

# Then, we construct a `LibraryModel` struct. The `TomoPhantom` library maintains standard digital phantoms in binary `.dat` structures.
# `default_2d_library_path()` automatically resolves exactly where `Phantom2DLibrary.dat` was compiled during package configuration.
# The ID identifies the specific phantom inside that library file (for example, `4` maps to a Modified Shepp-Logan variant).

model = LibraryModel(4, default_2d_library_path())

# ## Generating the Phantom Matrix
# Next, we invoke `phantom2d`. You only need to supply the native `core` binding, the chosen `model`, and the generic Cartesian grid size parameter `N`.
# For 2D, this determines an output matrix of size `N x N`.

N = 256
phantom_matrix = phantom2d(core, model, N)

# The result is automatically emitted natively as a Julia multi-dimensional `Array{Float32, 2}`.

println("Phantom matrix dimensions: ", size(phantom_matrix))
println("Maximum material intensity: ", maximum(phantom_matrix))
println("Number of structural (non-zero) elements: ", count(>(0), phantom_matrix))
