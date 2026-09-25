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
- `jitter_projections::Real=0.0`: Random directional jitter amplitude (in pixel units) applied to projections.
- `flatsnum::Int=20`: Number of flat field images to generate.
- `rng::AbstractRNG=Random.default_rng()`: Random number generator.

Returns `(proj_data_3d_raw, flats_3d, blurred_speckles_map)` where `proj_data_3d_raw` and `flats_3d` are `UInt16`.
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
    jitter_projections::Real=0.0,
    flatsnum::Int=20,
    rng::AbstractRNG=Random.default_rng()
)
    det_v, proj_no, det_h = size(proj_data_3d_clean)

    # Output containers
    flats_3d = zeros(UInt16, det_v, flatsnum, det_h)
    proj_data_3d_raw_float = zeros(Float32, det_v, proj_no, det_h)

    # Normalize input projection data
    max_clean = maximum(proj_data_3d_clean)
    proj_clean_norm = max_clean > 0 ? Float32.(proj_data_3d_clean ./ max_clean) : Float32.(proj_data_3d_clean)

    # --- SOURCE PROFILE (Bessel background) ---
    bessel_range = range(arguments_Bessel[1], arguments_Bessel[2], length=det_v)
    func = [sphericalbessely(1, Float32(x)) for x in bessel_range]
    func .+= abs(minimum(func))

    flatfield = zeros(Float32, det_v, det_h)
    for j in 1:det_h
        flatfield[:, j] .= func
    end
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

    # --- MODEL MISCALIBRATED DETECTORS ---
    blurred_speckles_map = zeros(Float32, det_v, det_h, variations_number)
    if detectors_miscallibration > 0 && variations_number > 0
        for j in 1:variations_number
            v_speckles = _simulate_speckles(det_v, det_h, 10, 0.03, rng)
            v_blurred = _simple_gaussian_blur(v_speckles, sigmasmooth)
            max_v = maximum(v_blurred)
            if max_v > 0
                v_blurred[v_blurred .< 0.6f0 * max_v] .= 0.0f0
            end
            blurred_speckles_map[:, :, j] .= v_blurred
        end
        max_m = maximum(blurred_speckles_map)
        if max_m > 0
            blurred_speckles_map ./= max_m
        end
    end

    # Angular response functions for detector miscalibration (upstream)
    sinusoidal_response = sin.(range(0.0f0, 1.5f0 * Float32(π), length=proj_no)) .+ rand(rng, Float32, proj_no) .* 0.1f0
    max_sin = maximum(sinusoidal_response)
    if max_sin > 0
        sinusoidal_response ./= max_sin
    end

    exponential_response = exp.(range(0.0f0, Float32(π), length=proj_no)) .+ rand(rng, Float32, proj_no) .* 0.1f0
    max_exp = maximum(exponential_response)
    if max_exp > 0
        exponential_response ./= max_exp
    end

    # --- FLAT-FIELD GENERATION ---
    max_speckle = maximum(speckle_background)
    speckle_norm = max_speckle > 0 ? speckle_background ./ max_speckle : speckle_background

    flatfield_combined = copy(flatfield) .+ 0.5f0 .* speckle_norm
    max_ff = maximum(flatfield_combined)
    if max_ff > 0
        flatfield_combined ./= max_ff
    end

    flatfield_poisson_last = similar(flatfield_combined)

    for i in 1:flatsnum
        ff_counts = flatfield_combined .* Float32(source_intensity)
        ff_noisy = _add_poisson_noise(ff_counts, rng)
        max_ff_noisy = maximum(ff_noisy)
        if max_ff_noisy > 0
            flatfield_poisson_last = ff_noisy ./ max_ff_noisy
            flats_3d[:, i, :] .= UInt16.(clamp.(round.(flatfield_poisson_last .* 65535.0f0), 0, 65535))
        end
    end

    # --- RAW PROJECTION DATA GENERATION ---
    # Emulates Beer-Lambert transmission: I = exp(-mu * L) * I0 + miscalibration_offset
    for p in 1:proj_no
        proj_exp = exp.(-proj_clean_norm[:, p, :]) .* Float32(source_intensity) .* flatfield_poisson_last

        for j in 1:variations_number
            offset_factor = if j == 1
                1.0f0
            elseif j == 2
                sinusoidal_response[p]
            elseif j == 3
                exponential_response[p]
            else
                1.0f0
            end
            proj_exp .+= view(blurred_speckles_map, :, :, j) .* (Float32(detectors_miscallibration) * Float32(source_intensity) * offset_factor)
        end

        proj_noisy = _add_poisson_noise(proj_exp, rng)

        if abs(jitter_projections) > 0.0
            jit = Float64(abs(jitter_projections))
            horiz_shift = rand(rng, Float64) * (2.0 * jit) - jit
            vert_shift = rand(rng, Float64) * (2.0 * jit) - jit
            proj_noisy = _translate_subpixel(proj_noisy, vert_shift, horiz_shift; mode=:reflect)
        end

        proj_data_3d_raw_float[:, p, :] .= proj_noisy
    end

    max_raw = maximum(proj_data_3d_raw_float)
    proj_data_3d_raw = zeros(UInt16, det_v, proj_no, det_h)
    if max_raw > 0
        proj_data_3d_raw .= UInt16.(clamp.(round.((proj_data_3d_raw_float ./ max_raw) .* 65535.0f0), 0, 65535))
    end

    return (proj_data_3d_raw, flats_3d, blurred_speckles_map)
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

# Internal helper to add Poisson noise with electronic noise directly without logarithm transform
function _add_poisson_noise(expected_counts::AbstractMatrix{<:Real}, rng::AbstractRNG)
    sig = sqrt(11.0f0)
    rows, cols = size(expected_counts)
    out = zeros(Float32, rows, cols)
    for j in 1:cols, i in 1:rows
        λ = max(0.0, Float64(expected_counts[i, j]))
        noise_count = Float32(_poisson_sample(rng, λ) + sig * randn(rng))
        out[i, j] = max(0.0f0, noise_count)
    end
    return out
end
