# # Analytical Projections (Sinograms)
#
# Generating analytical projections natively enables inverse problem validation without discretization errors masking numerical problems inside solvers.

using TomoPhantom

# ## Projection Geometry Definition
# 
# For tomographic setups, we must define the bounds of our projection rays. In `TomoPhantom.jl`, we use `SinoGeom2D` internally mapping our acquisition parameters:
# - `phantom_size`: The reference grid density (e.g. 256 implies `-1.0` to `1.0` spans 256 pixel equivalents).
# - `detector_u`: The amount of distinct linear detector array measurements.
# - `angles_deg`: A vector describing explicitly the subset of angles to trace in degrees.

angles = collect(Float32, range(0.0f0, 179.0f0; length=180))
geom = SinoGeom2D(256, 300, angles)

# ## Capturing Native Sinograms
#
# Let's project a pre-configured library model mathematically into sinogram space executing `sino2d_natural`.

core = NativeCore()
model = LibraryModel(1, default_2d_library_path())

sino_matrix = sino2d_natural(core, model, geom)

# The C engine canonically returns projections tracking angles as the outermost iterator to maintain extreme cache efficiency for path integrations.
# Consequently, the Julia multidimensional array lands safely populated with dimensionality `(angles, detectors)`.

println("Natural Sinogram dimensions: ", size(sino_matrix))

# ## Transposition Adapters for Algorithm Toolboxes
#
# If you are passing this benchmark Sinogram into ASTRA Toolbox, ODL, or standard Python bridging algorithms, they typically assume `(detectors, angles)` ordering implicitly. 
# You can flip the view structure instantly leveraging our explicitly exposed zero-cost view adapters.

sino_view = sino2d_u_angle_view(sino_matrix)
println("Adapter Transposed dimensions: ", size(sino_view))
