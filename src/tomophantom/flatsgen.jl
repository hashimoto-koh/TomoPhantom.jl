using Random
using SpecialFunctions
using FFTW

"""
    synth_flats(proj_data_3d_clean, source_intensity; kwargs...)

Generate synthetic flat field images and raw data for projection data normalisation.
This is a Julia port of the upstream `flatsgen.py` implementation.

**Arguments**:
- `proj_data_3d_clean`: Clean 3D projection data `[V, Angle, H]`.
- `source_intensity`: Target photon count for the source profile.

**Keyword Arguments**:
- `detectors_miscallibration::Real=0.05`: Degree of detector miscalibration.
- `variations_number::Int=3`: Number of variation maps for miscalibration.
- `arguments_Bessel::Tuple{Real, Real}=(1.0, 25.0)`: Range for the Bessel background.
- `specklesize::Int=2`: Size of the speckle patterns.
- `kbar::Real=2.0`: Average intensity of the speckles.
- `sigmasmooth::Int=3`: Smoothing factor for miscalibration maps.
- `flatsnum::Int=20`: Number of flat field images to generate.
- `rng::AbstractRNG=Random.default_rng()`: Random number generator.

Returns `(flats_3d, proj_data_3d_raw)` where `flats_3d` is `[V, flatsnum, H]` in `UInt16`.
"""
function synth_flats(
    proj_data_3d_clean::AbstractArray{<:Real, 3},
    source_intensity::Real;
    detectors_miscallibration::Real=0.05,
    variations_number::Int=3,
    arguments_Bessel::Tuple{<:Real, <:Real}=(1.0, 25.0),
    specklesize::Int=2,
    kbar::Real=2.0,
    sigmasmooth::Int=3,
    flatsnum::Int=20,
    rng::AbstractRNG=Random.default_rng()
)
    det_v, proj_no, det_h = size(proj_data_3d_clean)

    # Output containers
    flats_3d = zeros(UInt16, det_v, flatsnum, det_h)
    proj_data_3d_raw = zeros(Float32, det_v, proj_no, det_h)

    # Normalize input data
    max_clean = maximum(proj_data_3d_clean)
    proj_norm = max_clean > 0 ? Float32.(proj_data_3d_clean ./ max_clean) : Float32.(proj_data_3d_clean)

    # --- SOURCE PROFILE (Bessel background) ---
    bessel_range = range(arguments_Bessel[1], arguments_Bessel[2], length=det_v)
    # spherical_yn(n, x) in Python is sphericalbessely(n, x) in SpecialFunctions.jl
    func = [sphericalbessely(1, Float32(x)) for x in bessel_range]
    func .+= abs(minimum(func))
    
    flatfield = zeros(Float32, det_v, det_h)
    for j in 1:det_h
        flatfield[:, j] .= func
    end
    # Flip and add as per upstream (creates a symmetric profile)
    func_flip = reverse(func)
    for j in 1:det_h
        flatfield[:, j] .+= func_flip
    end

    # --- SPOTS/DIRT (Speckle background) ---
    speckle_background = if specklesize > 0
        _simulate_speckles(det_v, det_h, specklesize, kbar, rng)
    else
        ones(Float32, det_v, det_h)
    end

    # Model miscalibrated detectors
    miscalib_map = zeros(Float32, det_v, det_h)
    if detectors_miscallibration > 0
        for _ in 1:variations_number
            v_speckles = _simulate_speckles(det_v, det_h, 10, 0.03, rng)
            # Simple Gaussian blur approximation for sigmasmooth
            v_blurred = _simple_gaussian_blur(v_speckles, sigmasmooth)
            # Thresholding
            max_v = maximum(v_blurred)
            v_blurred[v_blurred .< 0.6 * max_v] .= 0
            miscalib_map .+= v_blurred
        end
        max_m = maximum(miscalib_map)
        if max_m > 0
            miscalib_map ./= max_m
        end
    end

    # --- FLAT-FIELD GENERATION ---
    max_speckle = maximum(speckle_background)
    speckle_norm = max_speckle > 0 ? speckle_background ./ max_speckle : speckle_background

    for i in 1:flatsnum
        # Combine bessel background and speckles
        ff_combined = copy(flatfield) .+ 0.5f0 .* speckle_norm
        max_ff = maximum(ff_combined)
        if max_ff > 0
            ff_combined ./= max_ff
        end

        # Use the existing noise function from artefacts.jl (Poisson noise)
        # Note: TomoPhantom's Poisson noise logic expects data in [0, 1] and scales it
        ff_noisy = noise(ff_combined, source_intensity, "Poisson"; seed=rand(rng, Int), prelog=false)
        
        # Scaling to UInt16 (0 - 65535)
        max_ff_noisy = maximum(ff_noisy)
        if max_ff_noisy > 0
            flats_3d[:, i, :] .= UInt16.(clamp.(round.( (ff_noisy ./ max_ff_noisy) .* 65535), 0, 65535))
        end
    end

    # --- RAW PROJECTION DATA GENERATION ---
    # Apply flatfield and noise to the normalized clean projections
    # This emulates I = I0 * exp(-mu*L)
    for p in 1:proj_no
        # Base flat field for this projection
        ff = copy(flatfield) .+ 0.5f0 .* speckle_norm
        
        # Apply miscalibration
        ff .*= (1.0f0 .- Float32(detectors_miscallibration) .* miscalib_map)
        
        # Scale to source intensity
        # proj_norm is exp(-mu*L)
        transmission = ff .* proj_norm[:, p, :]
        max_t = maximum(transmission)
        if max_t > 0
            transmission ./= max_t
        end
        
        # Add noise
        proj_noisy = noise(transmission, source_intensity, "Poisson"; seed=rand(rng, Int), prelog=false)
        proj_data_3d_raw[:, p, :] .= Float32.(proj_noisy)
    end

    return flats_3d, proj_data_3d_raw
end

# Internal helper to simulate speckle texture.
function _simulate_speckles(rows::Int, cols::Int, size_val::Int, kbar::Real, rng::AbstractRNG)
    # Simple speckle simulation using random phases and FFT
    # This is a common way to generate speckle-like patterns
    phases = exp.(2π * im .* rand(rng, Float32, rows, cols))
    
    # Low-pass filter in Fourier space to control speckle size
    F = fft(phases)
    # Control size by zeroing out high frequencies
    # This is a simplification of the upstream's speckle generator
    cutoff_r = rows / (2 * size_val)
    cutoff_c = cols / (2 * size_val)
    for j in 1:cols, i in 1:rows
        dist_i = min(abs(i-1), abs(i-1-rows))
        dist_j = min(abs(j-1), abs(j-1-cols))
        if dist_i > cutoff_r || dist_j > cutoff_c
            F[i, j] = 0
        end
    end
    
    speckles = abs2.(ifft(F))
    max_s = maximum(speckles)
    if max_s > 0
        speckles .*= (Float32(kbar) / max_s)
    end
    return Float32.(speckles)
end

# Internal helper for simple box-blur based Gaussian approximation.
function _simple_gaussian_blur(data::AbstractMatrix{Float32}, sigma::Int)
    sigma <= 0 && return copy(data)
    # Use the internal _convolve_same from artefacts.jl if possible, 
    # but that's 1D. We'll use a simple 2D blur.
    rows, cols = size(data)
    out = copy(data)
    # 2 passes of box blur is a fair approximation
    for _ in 1:2
        tmp = copy(out)
        for j in 1:cols, i in 1:rows
            acc = 0.0f0
            count = 0
            for dj in -sigma:sigma, di in -sigma:sigma
                ni, nj = i + di, j + dj
                if 1 <= ni <= rows && 1 <= nj <= cols
                    acc += tmp[ni, nj]
                    count += 1
                end
            end
            out[i, j] = acc / count
        end
    end
    return out
end
