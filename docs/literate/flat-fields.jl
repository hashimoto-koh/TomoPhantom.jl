# # Flat-field Synthesis
#
# This tutorial demonstrates how to generate synthetic flat-field ($I_0$) images and raw transmission data ($I$) using `TomoPhantom.jl`. 
# Flat-field synthesis is useful for simulating realistic tomographic datasets where non-uniform source beam profiles, detector dust/scintillator defects, pixel sensitivity variations (causing stripe artifacts), and Poisson photon noise are present.

using TomoPhantom
using Random
using Statistics

# ## 1. Generating Clean 3D Projection Data
# 
# First, we generate clean analytical 3D projection data using standard models (e.g. Model 13: 3D Shepp-Logan).

core = NativeCore()
model = LibraryModel(13, default_3d_library_path())
geom = SinoGeom3D(64, 64, 64, collect(Float32, range(0.0f0, 179.0f0; length=90)), 0, 64)

# `sino3d_natural` evaluates analytical projections, returning `[Horiz_det, Vert_det, Angle]`.
sino_clean = sino3d_natural(core, model, geom)

# `synth_flats` expects projection data in `[Vert_det, Angle, Horiz_det]` order.
proj_clean = permutedims(sino_clean, (2, 3, 1))
println("Clean projection size [V, Angle, H]: ", size(proj_clean))

# ## 2. Synthesizing Flat-Fields and Raw Transmission Data (`synth_flats`)
#
# `synth_flats` accepts clean projection data and incident source intensity, along with parameters controlling noise, detector miscalibration, and mechanical wobble (jitter).
#
# Parameters:
# - `source_intensity::Real`: Incident photon flux level (controls Poisson noise SNR).
# - `flatsnum::Int`: Number of flat-field images to generate.
# - `detectors_miscallibration::Real`: Relative pixel sensitivity variation strength (causes ring/stripe artifacts).
# - `jitter_projections::Real`: Random mechanical axis wobble / jitter amplitude (in pixels).
# - `sigmasmooth::Int`: Gaussian blur parameter for miscalibration patches.

proj_raw, flats, speckles_map = synth_flats(
    proj_clean,
    30000;
    flatsnum = 15,
    detectors_miscallibration = 0.05,
    jitter_projections = 0.5,
    sigmasmooth = 3,
)

println("Raw transmission data shape: ", size(proj_raw), "  type: ", eltype(proj_raw), "  range: ", extrema(proj_raw))
println("Flat-field images shape:     ", size(flats), "  type: ", eltype(flats), "  range: ", extrema(flats))
println("Sensitivity defect map shape: ", size(speckles_map))

# Notice that both `proj_raw` and `flats` are `UInt16` count values representing physical pre-log photon transmission measurements.

# ## 3. Flat-Field Normalization and Log-Correction (Beer-Lambert Law)
#
# With synthetic pre-log data, we can apply standard CT pre-processing to retrieve the true line integrals (absorbance):
#
# 1. **Master Flat Calculation**: Average multiple flat fields to suppress Poisson noise:
#    $$\bar{I}_{\text{flat}} = \frac{1}{N_{\text{flat}}} \sum_{k=1}^{N_{\text{flat}}} I_{\text{flat}, k}$$
#
# 2. **Transmittance & Absorbance Conversion**:
#    $$T = \frac{I_{\text{raw}}}{\bar{I}_{\text{flat}}}, \quad P = -\ln(T) = \int \mu \, ds$$

# Calculate master flat (adding a tiny epsilon to prevent division by zero)
flat_ref = dropdims(mean(Float32.(flats), dims=2), dims=2) .+ 1.0f-5
raw_float = Float32.(proj_raw)

# Compute transmittance and negative logarithm
proj_normalized = zeros(Float32, size(proj_raw))
for a in 1:size(proj_raw, 2)
    transmittance = clamp.(raw_float[:, a, :] ./ flat_ref, 1.0f-6, 1.0f0)
    proj_normalized[:, a, :] .= -log.(transmittance)
end

println("Normalized sinogram ready for reconstruction: ", size(proj_normalized))
