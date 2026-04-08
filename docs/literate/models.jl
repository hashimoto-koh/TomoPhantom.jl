# # Analytical Shape Models
#
# Often, utilizing hardcoded library models isn't enough when you need hyper-customizable shapes for benchmarking features (like resolution recovery mapping or noise testing). `TomoPhantom.jl` maps the primitive definition API exposing powerful single-object generators.

using TomoPhantom

# ## 2D Object Construction
# 
# You define shapes analytically utilizing parameter objects. `ObjectSpec2D` maps standard mathematical definitions down to the C interpreter level.
# 
# Parameters exposed inside `ObjectSpec2D`:
# - `object`: Mathematical primitive ("gaussian", "ellipse", "rectangle", "parabola").
# - `C0`: Overall constant intensity (Amplitude).
# - `x0`, `y0`: Cartesian center displacement offsets ranging canonically from `[-1.0, 1.0]`.
# - `a`, `b`: Semi-axis scales stretching the primitive boundaries.
# - `phi_rot`: Euler rotation boundary applied to the structure (in degrees).

spec2d = ObjectSpec2D(
    object="gaussian", 
    C0=2.0f0, 
    x0=0.0f0, y0=-0.3f0, 
    a=0.15f0, b=0.4f0, 
    phi_rot=45.0f0
)

# Generating the object requires passing the `NativeCore`, output array dimensionality `N`, and the specification object `spec2d`.

core = NativeCore()
N = 128
obj2d_matrix = object2d(core, N, spec2d)

println("2D Object produced size: ", size(obj2d_matrix))
println("Peak focal intensity measured: ", maximum(obj2d_matrix))

# ## 3D Object Construction
#
# Moving into Volumetric structures, we use `ObjectSpec3D` which naturally exposes additional `z` coordinate dimensions, the `c` axis modifier, and dual-axis rotational parameters `phi1`, `phi2`, and `phi3`.

spec3d = ObjectSpec3D(
    object="ellipsoid", 
    C0=1.0f0,
    a=0.3f0, b=0.2f0, c=0.2f0,
    x0=0.1f0, y0=0.1f0, z0=-0.1f0
)

# Render a volumetric element grid (e.g., `[64, 64, 64]`) 
obj3d_matrix = object3d(core, 64, spec3d)

println("3D Object structure dimensionality: ", size(obj3d_matrix))
