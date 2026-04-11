"""
    QualityTools(im1, im2)

Container for pairwise image or volume quality comparisons.
The two inputs must have identical shapes.
"""
struct QualityTools{N}
    im1::Array{Float32,N}
    im2::Array{Float32,N}
end

function QualityTools(im1::AbstractArray{<:Real}, im2::AbstractArray{<:Real})
    size(im1) == size(im2) || throw(ArgumentError("Sizes of images/volumes are different"))
    return QualityTools{ndims(im1)}(Float32.(im1), Float32.(im2))
end

function _reverse_all_dims(A::AbstractArray)
    B = A
    for d in 1:ndims(A)
        B = reverse(B; dims=d)
    end
    return B
end

function _conv_valid(data::AbstractArray{<:Real,N}, kernel::AbstractArray{<:Real,N}) where {N}
    all(size(kernel, d) <= size(data, d) for d in 1:N) || return nothing
    out_size = ntuple(d -> size(data, d) - size(kernel, d) + 1, N)
    out = zeros(Float32, out_size)
    dataf = Float32.(data)
    kernelf = Float32.(_reverse_all_dims(kernel))
    for I in CartesianIndices(out)
        acc = 0.0f0
        for K in CartesianIndices(kernelf)
            src = ntuple(d -> I[d] + K[d] - 1, N)
            acc += dataf[src...] * kernelf[K]
        end
        out[I] = acc
    end
    return out
end

"""
    rmse(qt::QualityTools)
    rmse(im1, im2)

Root mean square error.
"""
function rmse(qt::QualityTools)
    return sqrt(sum(abs2, qt.im1 .- qt.im2) / length(qt.im1))
end

rmse(im1::AbstractArray{<:Real}, im2::AbstractArray{<:Real}) = rmse(QualityTools(im1, im2))

"""
    nrmse(qt::QualityTools)
    nrmse(im1, im2)

Normalised root mean square error, following upstream `qualitymetrics.py`.
"""
function nrmse(qt::QualityTools)
    err = rmse(qt)
    max_val = max(maximum(qt.im1), maximum(qt.im2))
    min_val = min(minimum(qt.im1), minimum(qt.im2))
    scale = max_val - min_val
    scale == 0 && return err == 0 ? 1.0f0 : -Inf32
    return 1.0f0 - (err / scale)
end

nrmse(im1::AbstractArray{<:Real}, im2::AbstractArray{<:Real}) = nrmse(QualityTools(im1, im2))

"""
    ssim(qt::QualityTools, window; k=(0.01, 0.03), l=255)
    ssim(im1, im2, window; k=(0.01, 0.03), l=255)

Structural similarity index and map.
Returns `(mssim, ssim_map)` or `(nothing, nothing)` for invalid inputs.
"""
function ssim(
    qt::QualityTools,
    window::AbstractArray{<:Real};
    k::Tuple{<:Real,<:Real}=(0.01, 0.03),
    l::Real=255,
)
    ndims(window) == ndims(qt.im1) || return nothing, nothing
    all(size(window, d) <= size(qt.im1, d) for d in 1:ndims(window)) || return nothing, nothing
    all(ki >= 0 for ki in k) || return nothing, nothing

    windowf = Float32.(window)
    window_sum = sum(windowf)
    window_sum == 0 && return nothing, nothing
    windowf ./= window_sum

    c1 = Float32((k[1] * l)^2)
    c2 = Float32((k[2] * l)^2)

    mu1 = _conv_valid(qt.im1, windowf)
    mu2 = _conv_valid(qt.im2, windowf)
    if isnothing(mu1) || isnothing(mu2)
        return nothing, nothing
    end

    mu1_sq = mu1 .* mu1
    mu2_sq = mu2 .* mu2
    mu1_mu2 = mu1 .* mu2

    sigma1_sq = _conv_valid(qt.im1 .* qt.im1, windowf) .- mu1_sq
    sigma2_sq = _conv_valid(qt.im2 .* qt.im2, windowf) .- mu2_sq
    sigma12 = _conv_valid(qt.im1 .* qt.im2, windowf) .- mu1_mu2

    ssim_map = similar(mu1)
    if c1 > 0 && c2 > 0
        num = (2.0f0 .* mu1_mu2 .+ c1) .* (2.0f0 .* sigma12 .+ c2)
        den = (mu1_sq .+ mu2_sq .+ c1) .* (sigma1_sq .+ sigma2_sq .+ c2)
        ssim_map .= num ./ den
    else
        num1 = 2.0f0 .* mu1_mu2 .+ c1
        num2 = 2.0f0 .* sigma12 .+ c2
        den1 = mu1_sq .+ mu2_sq .+ c1
        den2 = sigma1_sq .+ sigma2_sq .+ c2
        ssim_map .= 1.0f0
        positive = (den1 .* den2) .> 0
        ssim_map[positive] .= (num1[positive] .* num2[positive]) ./ (den1[positive] .* den2[positive])
        mixed = (den1 .!= 0) .& (den2 .== 0)
        ssim_map[mixed] .= num1[mixed] ./ den1[mixed]
    end
    return sum(ssim_map) / length(ssim_map), ssim_map
end

ssim(im1::AbstractArray{<:Real}, im2::AbstractArray{<:Real}, window::AbstractArray{<:Real}; kwargs...) =
    ssim(QualityTools(im1, im2), window; kwargs...)
