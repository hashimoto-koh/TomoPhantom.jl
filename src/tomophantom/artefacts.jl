_artefact_rng(seed) = seed isa AbstractRNG ? seed :
                      seed isa Integer ? MersenneTwister(abs(seed)) :
                      seed === true ? MersenneTwister(1) :
                      Random.default_rng()

function _gaussian_kernel1d(sigma::Int)
    sigma > 0 || throw(ArgumentError("Smoothing kernel must be positive"))
    radius = max(1, ceil(Int, 3 * sigma))
    kernel = Float32[exp(-(x * x) / (2f0 * sigma * sigma)) for x in -radius:radius]
    kernel ./= sum(kernel)
    return kernel
end

function _convolve_same(signal::AbstractVector{<:Real}, kernel::AbstractVector{<:Real})
    radius = length(kernel) ÷ 2
    out = zeros(Float32, length(signal))
    for i in eachindex(signal)
        acc = 0.0f0
        for (j, coeff) in enumerate(kernel)
            src = i + j - radius - 1
            if 1 <= src <= length(signal)
                acc += Float32(coeff) * Float32(signal[src])
            end
        end
        out[i] = acc
    end
    return out
end

function _convolve_same(slice::AbstractMatrix{<:Real}, kernel::AbstractVector{<:Real})
    tmp = similar(Float32.(slice))
    out = similar(Float32.(slice))
    for j in axes(slice, 2)
        tmp[:, j] = _convolve_same(view(slice, :, j), kernel)
    end
    for i in axes(tmp, 1)
        out[i, :] = _convolve_same(view(tmp, i, :), kernel)
    end
    return out
end

function _shift_with_zeros(signal::AbstractVector{<:Real}, shift::Int)
    out = zeros(Float32, length(signal))
    for i in eachindex(signal)
        dest = i + shift
        if 1 <= dest <= length(signal)
            out[dest] = Float32(signal[i])
        end
    end
    return out
end

function _shift_with_zeros(slice::AbstractMatrix{<:Real}, shift_y::Int, shift_x::Int)
    out = zeros(Float32, size(slice))
    for j in axes(slice, 2), i in axes(slice, 1)
        dest_i = i + shift_y
        dest_j = j + shift_x
        if 1 <= dest_i <= size(slice, 1) && 1 <= dest_j <= size(slice, 2)
            out[dest_i, dest_j] = Float32(slice[i, j])
        end
    end
    return out
end

function _reflect_coord(c::Float64, n::Int)
    n <= 1 && return 1.0
    while c < 1.0 || c > Float64(n)
        if c < 1.0
            c = 2.0 - c
        elseif c > Float64(n)
            c = 2.0 * Float64(n) - c
        end
    end
    return c
end

function _bilinear_get(slice::AbstractMatrix{<:Real}, y::Float64, x::Float64; mode::Symbol=:zero)
    H, W = size(slice)
    if mode == :reflect
        y = _reflect_coord(y, H)
        x = _reflect_coord(x, W)
    elseif mode == :nearest
        y = clamp(y, 1.0, Float64(H))
        x = clamp(x, 1.0, Float64(W))
    else
        if !(1.0 <= y <= Float64(H) && 1.0 <= x <= Float64(W))
            return 0.0f0
        end
    end
    y0 = min(floor(Int, y), H)
    x0 = min(floor(Int, x), W)
    y1 = min(y0 + 1, H)
    x1 = min(x0 + 1, W)
    dy = Float32(y - y0)
    dx = Float32(x - x0)
    v00 = Float32(slice[y0, x0])
    v10 = Float32(slice[y1, x0])
    v01 = Float32(slice[y0, x1])
    v11 = Float32(slice[y1, x1])
    return (1f0 - dy) * ((1f0 - dx) * v00 + dx * v01) + dy * ((1f0 - dx) * v10 + dx * v11)
end

function _translate_subpixel(slice::AbstractMatrix{<:Real}, shift_y::Float64, shift_x::Float64; mode::Symbol=:zero)
    out = zeros(Float32, size(slice))
    for j in axes(slice, 2), i in axes(slice, 1)
        out[i, j] = _bilinear_get(slice, Float64(i) - shift_y, Float64(j) - shift_x; mode=mode)
    end
    return out
end

function _poisson_sample(rng::AbstractRNG, λ::Float64)
    λ <= 0 && return 0.0
    if λ < 30.0
        l = exp(-λ)
        k = 0
        p = 1.0
        while p > l
            k += 1
            p *= rand(rng)
        end
        return Float64(k - 1)
    end
    return max(0.0, round(λ + sqrt(λ) * randn(rng)))
end

"""
    zingers(data, percentage, modulus)

Add zingers to 2D sinograms or 3D projection data.
"""
function zingers(data::AbstractArray{<:Real}, percentage::Real, modulus::Integer)
    ndims(data) in (2, 3) || throw(ArgumentError("data must be 2D or 3D"))
    0.0 < percentage <= 100.0 || throw(ArgumentError("percentage must be larger than zero but smaller than 100"))
    modulus > 0 || throw(ArgumentError("Modulus integer must be positive"))
    out = Float32.(data)
    total = length(out)
    num_values = round(Int, total * (Float32(percentage) / 100f0))
    inds = CartesianIndices(out)
    for x in 1:num_values
        idx = inds[rand(1:length(inds))]
        out[idx] = 0.0f0
        if x % modulus == 0
            if ndims(out) == 2
                i, j = Tuple(idx)
                for (di, dj) in ((0, 1), (0, -1), (1, 0), (-1, 0))
                    ii = i + di
                    jj = j + dj
                    if 1 <= ii <= size(out, 1) && 1 <= jj <= size(out, 2)
                        out[ii, jj] = 0.0f0
                    end
                end
            else
                i, j, k = Tuple(idx)
                for (di, dj, dk) in ((0, 0, 1), (0, 0, -1), (1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0))
                    ii = i + di
                    jj = j + dj
                    kk = k + dk
                    if 1 <= ii <= size(out, 1) && 1 <= jj <= size(out, 2) && 1 <= kk <= size(out, 3)
                        out[ii, jj, kk] = 0.0f0
                    end
                end
            end
        end
    end
    return out
end

"""
    stripes(data, percentage, maxthickness, intensity_thresh, stripe_type, variability)

Add stripe artefacts to 2D sinograms or 3D projection data.
"""
function stripes(
    data::AbstractArray{<:Real},
    percentage::Real,
    maxthickness::Integer,
    intensity_thresh::Real,
    stripe_type::AbstractString,
    variability::Real,
)
    ndims(data) in (2, 3) || throw(ArgumentError("data must be 2D or 3D"))
    0.0 < percentage <= 100.0 || throw(ArgumentError("percentage must be larger than zero but smaller than 100"))
    0 <= maxthickness <= 10 || throw(ArgumentError("maximum thickness must be in [0,10] range"))
    out = Float32.(data)
    max_intensity = maximum(out)
    if ndims(out) == 2
        angles_dim, det_h = size(out)
        range_detect = floor(Int, Float32(det_h) * (Float32(percentage) / 100f0))
        for _ in 1:range_detect
            randind = rand(1:det_h)
            for _ in 1:20
                out[1, randind] != 0.0f0 && break
                randind = rand(1:det_h)
            end
            randthickness = rand(0:maxthickness)
            randintens = rand() * 1.5f0 - 1.0f0
            intensity = max_intensity * randintens * Float32(intensity_thresh)
            ang1, ang2 = stripe_type == "partial" ? (rand(1:angles_dim), rand(1:angles_dim)) : (1, angles_dim)
            if randind > 1 + randthickness && randind < det_h - randthickness && ang1 <= ang2
                for offset in -randthickness:randthickness
                    intensity_off = variability != 0 ? Float32(variability) * max_intensity : 0.0f0
                    for ll in ang1:ang2
                        out[ll, randind + offset] += intensity + intensity_off
                        intensity_off += (rand(Bool) ? 1f0 : -1f0) * Float32(variability) * max_intensity
                    end
                end
            end
        end
    else
        det_v, angles_dim, det_h = size(out)
        range_detect = floor(Int, Float32(det_h) * (Float32(percentage) / 100f0))
        for j in 1:det_v, _ in 1:range_detect
            randind = rand(1:det_h)
            for _ in 1:20
                out[j, 1, randind] != 0.0f0 && break
                randind = rand(1:det_h)
            end
            randthickness = rand(0:maxthickness)
            randintens = rand() * 1.5f0 - 1.0f0
            intensity = max_intensity * randintens * Float32(intensity_thresh)
            ang1, ang2 = stripe_type == "partial" ? (rand(1:angles_dim), rand(1:angles_dim)) : (1, angles_dim)
            if randind > 1 + randthickness && randind < det_h - randthickness && ang1 <= ang2
                for offset in -randthickness:randthickness
                    intensity_off = variability != 0 ? Float32(variability) * max_intensity : 0.0f0
                    for ll in ang1:ang2
                        out[j, ll, randind + offset] += intensity + intensity_off
                        intensity_off += (rand(Bool) ? 1f0 : -1f0) * Float32(variability) * max_intensity
                    end
                end
            end
        end
    end
    return out
end

"""
    noise(data, sigma, noisetype; seed=true, prelog=false)

Add Gaussian or Poisson noise to N-dimensional data.
"""
function noise(
    data::AbstractArray{<:Real},
    sigma::Union{Integer,AbstractFloat},
    noisetype::AbstractString;
    seed::Union{Bool,Integer,AbstractRNG}=true,
    prelog::Bool=false,
)
    rng = _artefact_rng(seed)
    data_float = Float32.(data)
    max_data = maximum(data_float)
    max_data == 0 && return prelog ? (similar(data_float), similar(data_float)) : data_float
    data_noisy = data_float ./ max_data
    if noisetype == "Gaussian"
        data_noisy .+= Float32.(randn(rng, size(data_noisy))) .* Float32(sigma)
        data_noisy[data_noisy .< 0] .= 0
        data_noisy .*= max_data
        return data_noisy
    elseif noisetype == "Poisson"
        ri = 1.0f0
        sig = sqrt(11.0f0)
        yb = Float64.(Float32(sigma) .* exp.(-data_noisy) .+ ri)
        data_raw = similar(data_noisy)
        for idx in eachindex(yb)
            data_raw[idx] = Float32(_poisson_sample(rng, yb[idx]) + sqrt(sig) * randn(rng))
        end
        noisy = similar(data_noisy)
        for idx in eachindex(data_raw)
            if data_raw[idx] - ri <= 0
                noisy[idx] = 0.0f0
            else
                noisy[idx] = Float32(-log((data_raw[idx] - ri) / Float32(sigma)) * max_data)
            end
        end
        return prelog ? (noisy, data_raw) : noisy
    else
        throw(ArgumentError("Select 'Gaussian' or 'Poisson' for the noise type"))
    end
end

"""
    datashifts(data, maxamplitude)

Add integer data shifts to 2D sinograms or 3D projection data.
"""
function datashifts(data::AbstractArray{<:Real}, maxamplitude::Integer)
    ndims(data) in (2, 3) || throw(ArgumentError("data must be 2D or 3D"))
    if ndims(data) == 2
        angles_dim, _ = size(data)
        shifts = zeros(Int8, angles_dim)
        shifted = zeros(Float32, size(data))
        for x in 1:angles_dim
            rand_shift = rand(-maxamplitude:maxamplitude)
            shifts[x] = Int8(rand_shift)
            shifted[x, :] = _shift_with_zeros(view(data, x, :), rand_shift)
        end
    else
        _, angles_dim, _ = size(data)
        shifts = zeros(Int8, angles_dim, 2)
        shifted = zeros(Float32, size(data))
        for x in 1:angles_dim
            rand_shift_y = rand(-maxamplitude:maxamplitude)
            rand_shift_x = rand(-maxamplitude:maxamplitude)
            shifts[x, 1] = Int8(rand_shift_x)
            shifts[x, 2] = Int8(rand_shift_y)
            shifted[:, x, :] = _shift_with_zeros(view(data, :, x, :), rand_shift_y, rand_shift_x)
        end
    end
    return shifted, shifts
end

"""
    datashifts_subpixel(data, maxamplitude)

Add subpixel data shifts to 2D sinograms or 3D projection data.
"""
function datashifts_subpixel(data::AbstractArray{<:Real}, maxamplitude::Real)
    ndims(data) in (2, 3) || throw(ArgumentError("data must be 2D or 3D"))
    if ndims(data) == 2
        shift_x = rand() * (2 * Float64(maxamplitude)) - Float64(maxamplitude)
        shift_y = rand() * (2 * Float64(maxamplitude)) - Float64(maxamplitude)
        shifts = reshape(Float32[shift_x, shift_y], 1, 2)
        shifted = _translate_subpixel(Float32.(data), shift_y, shift_x)
    else
        _, angles_dim, _ = size(data)
        shifts = zeros(Float32, angles_dim, 2)
        shifted = zeros(Float32, size(data))
        data_float = Float32.(data)
        for x in 1:angles_dim
            shift_x = rand() * (2 * Float64(maxamplitude)) - Float64(maxamplitude)
            shift_y = rand() * (2 * Float64(maxamplitude)) - Float64(maxamplitude)
            shifts[x, 1] = Float32(shift_x)
            shifts[x, 2] = Float32(shift_y)
            shifted[:, x, :] = _translate_subpixel(view(data_float, :, x, :), shift_y, shift_x)
        end
    end
    return shifted, shifts
end

"""
    jitter_projections(data, jitter; rng=Random.default_rng(), mode=:reflect)

Add random 2D directional shifts (jitter) within `[-jitter, jitter]` to each projection in 3D projection data `[V, Angle, H]` (or 1D horizontal shifts for 2D sinograms).
"""
function jitter_projections(
    data::AbstractArray{<:Real},
    jitter::Real;
    rng::AbstractRNG=Random.default_rng(),
    mode::Symbol=:reflect,
)
    abs(jitter) == 0 && return copy(Float32.(data))
    ndims(data) in (2, 3) || throw(ArgumentError("data must be 2D or 3D"))
    jit = Float64(abs(jitter))
    if ndims(data) == 2
        angles_dim, _ = size(data)
        out = similar(Float32.(data))
        for a in 1:angles_dim
            shift_x = rand(rng, Float64) * (2.0 * jit) - jit
            slice_1d = reshape(view(data, a, :), 1, :)
            out[a, :] = vec(_translate_subpixel(slice_1d, 0.0, shift_x; mode=mode))
        end
        return out
    else
        det_v, angles_dim, det_h = size(data)
        out = zeros(Float32, det_v, angles_dim, det_h)
        for a in 1:angles_dim
            shift_x = rand(rng, Float64) * (2.0 * jit) - jit
            shift_y = rand(rng, Float64) * (2.0 * jit) - jit
            out[:, a, :] = _translate_subpixel(view(data, :, a, :), shift_y, shift_x; mode=mode)
        end
        return out
    end
end

"""
    pve(data, pve_strength)

Apply a partial volume effect approximation by Gaussian smoothing each projection.
"""
function pve(data::AbstractArray{<:Real}, pve_strength::Integer)
    kernel = _gaussian_kernel1d(pve_strength)
    out = similar(Float32.(data))
    if ndims(data) == 2
        angles_dim, _ = size(data)
        for x in 1:angles_dim
            out[x, :] = _convolve_same(view(data, x, :), kernel)
        end
    elseif ndims(data) == 3
        _, angles_dim, _ = size(data)
        for x in 1:angles_dim
            out[:, x, :] = _convolve_same(view(data, :, x, :), kernel)
        end
    else
        throw(ArgumentError("data must be 2D or 3D"))
    end
    return out
end

"""
    fresnel_propagator(data, dist_observation, scale_factor, wavelenght)

Apply a Fresnel propagator to 2D sinograms or 3D projection data.
"""
function fresnel_propagator(
    data::AbstractArray{<:Real},
    dist_observation::Integer,
    scale_factor::Real,
    wavelenght::Real,
)
    out = Float32.(data)
    if ndims(data) == 2
        angles_dim, det_h = size(data)
        n1 = det_h * 0.5
        u = collect(-n1:(n1 - 1))
        propagator = exp.(2π * im * (dist_observation / scale_factor) .* sqrt.(Complex.((1 / wavelenght)^2 .- (u ./ 10) .^ 2)))
        for x in 1:angles_dim
            field = FFTW.fftshift(fft(view(out, x, :))) .* propagator
            out[x, :] = abs.(ifft(field))
        end
    elseif ndims(data) == 3
        det_v, angles_dim, det_h = size(data)
        n1 = det_v * 0.5
        n2 = det_h * 0.5
        u = collect(-n1:(n1 - 1))
        v = collect(-n2:(n2 - 1))
        propagator = [exp(2π * im * (dist_observation / scale_factor) *
                          sqrt(Complex((1 / wavelenght)^2 - (uu / scale_factor)^2 - (vv / scale_factor)^2)))
                      for uu in u, vv in v]
        for x in 1:angles_dim
            field = FFTW.fftshift(fft(view(out, :, x, :))) .* propagator
            out[:, x, :] = abs.(ifft(field))
        end
    else
        throw(ArgumentError("data must be 2D or 3D"))
    end
    return out
end

"""
    artefacts_mix(data; kwargs...)

Apply a mix of artefacts following the upstream `artefacts.py` order.
"""
function artefacts_mix(
    data::AbstractArray{<:Real};
    noise_type=nothing,
    noise_amplitude=1,
    noise_seed=true,
    noise_prelog::Bool=false,
    zingers_percentage=nothing,
    zingers_modulus::Integer=10,
    stripes_percentage=nothing,
    stripes_maxthickness::Integer=1,
    stripes_intensity::Real=0.25,
    stripes_type::AbstractString="full",
    stripes_variability::Real=0.0,
    datashifts_maxamplitude_pixel=nothing,
    datashifts_maxamplitude_subpixel=nothing,
    pve_strength=nothing,
    fresnel_dist_observation=nothing,
    fresnel_scale_factor::Real=10,
    fresnel_wavelenght::Real=0.0001,
    verbose::Bool=false,
)
    sino_artifacts = pve_strength === nothing ? Float32.(data) : Float32.(pve(data, pve_strength))
    if pve_strength !== nothing && verbose
        println("Partial volume effect (PVE) has been simulated.")
    end
    if fresnel_dist_observation !== nothing
        sino_artifacts = Float32.(fresnel_propagator(sino_artifacts, fresnel_dist_observation, fresnel_scale_factor, fresnel_wavelenght))
        verbose && println("Fresnel propagator has been simulated.")
    end
    if zingers_percentage !== nothing
        sino_artifacts = Float32.(zingers(sino_artifacts, zingers_percentage, zingers_modulus))
        verbose && println("Zingers have been added to the data.")
    end
    if stripes_percentage !== nothing
        sino_artifacts = Float32.(stripes(sino_artifacts, stripes_percentage, stripes_maxthickness, stripes_intensity, stripes_type, stripes_variability))
        verbose && println("Stripes leading to ring artefacts have been simulated.")
    end
    shifts = nothing
    if datashifts_maxamplitude_pixel !== nothing
        sino_artifacts, shifts = datashifts(sino_artifacts, datashifts_maxamplitude_pixel)
        verbose && println("Data shifts have been simulated.")
    end
    if datashifts_maxamplitude_subpixel !== nothing
        sino_artifacts, shifts = datashifts_subpixel(sino_artifacts, datashifts_maxamplitude_subpixel)
        verbose && println("Data shifts (in subpixel precision) have been simulated.")
    end
    if noise_type !== nothing
        noisy = noise(sino_artifacts, noise_amplitude, noise_type; seed=noise_seed, prelog=noise_prelog)
        verbose && println("$(noise_type) noise has been added to the data.")
        if shifts !== nothing
            return noise_prelog ? (Float32.(noisy[1]), Float32.(noisy[2]), shifts) : (Float32.(noisy), shifts)
        end
        return noise_prelog ? (Float32.(noisy[1]), Float32.(noisy[2])) : Float32.(noisy)
    end
    return shifts === nothing ? Float32.(sino_artifacts) : (Float32.(sino_artifacts), shifts)
end
