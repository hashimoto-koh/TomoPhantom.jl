using Test
using TomoPhantom
using Random

@testset "TomoPhantom.jl" begin
    result = TomoPhantom.selfcheck_step2()
    @test all(values(result.checks))
    @test result.shapes.phantom2d == (64, 64)
    @test result.shapes.sino2d_natural == (60, 91)
    @test result.shapes.phantom3d == (32, 32, 32)
    @test result.shapes.sino3d_natural == (96, 64, 45)
end

@testset "artefacts" begin
    data2 = reshape(Float32.(1:20), 4, 5)
    data3 = reshape(Float32.(1:60), 3, 4, 5)

    Random.seed!(123)
    z2 = TomoPhantom.zingers(data2, 10.0, 2)
    @test size(z2) == size(data2)
    @test count(iszero, z2) > 0

    Random.seed!(123)
    s2 = TomoPhantom.stripes(data2, 20.0, 1, 0.4, "full", 0.0)
    @test size(s2) == size(data2)
    @test any(abs.(s2 .- data2) .> 0)

    Random.seed!(123)
    shifted2, shifts2 = TomoPhantom.datashifts(data2, 1)
    @test size(shifted2) == size(data2)
    @test size(shifts2) == (4,)

    Random.seed!(123)
    shifted3, shifts3 = TomoPhantom.datashifts(data3, 1)
    @test size(shifted3) == size(data3)
    @test size(shifts3) == (4, 2)

    Random.seed!(123)
    sub2, subshifts2 = TomoPhantom.datashifts_subpixel(data2, 0.5)
    @test size(sub2) == size(data2)
    @test size(subshifts2) == (1, 2)

    gnoise = TomoPhantom.noise(data2, 0.01, "Gaussian"; seed=7)
    @test size(gnoise) == size(data2)

    pnoise, raw = TomoPhantom.noise(data2, 1000, "Poisson"; seed=7, prelog=true)
    @test size(pnoise) == size(data2)
    @test size(raw) == size(data2)

    pve2 = TomoPhantom.pve(data2, 1)
    @test size(pve2) == size(data2)

    fresnel2 = TomoPhantom.fresnel_propagator(data2, 10, 10.0, 0.0001)
    @test size(fresnel2) == size(data2)

    mix = TomoPhantom.artefacts_mix(data2; zingers_percentage=5.0, zingers_modulus=2, stripes_percentage=10.0, stripes_maxthickness=1, stripes_intensity=0.3)
    @test size(mix) == size(data2)

    Random.seed!(123)
    mix_shifted, mix_shifts = TomoPhantom.artefacts_mix(data3; datashifts_maxamplitude_pixel=1)
    @test size(mix_shifted) == size(data3)
    @test size(mix_shifts) == (4, 2)
end

@testset "foam generators" begin
    core = TomoPhantom.NativeCore()

    foam2, objects2 = TomoPhantom.foam2D(-0.8, 0.8, -0.8, 0.8, 0.2, 1.0, 0.05, 0.12, 32, 6, "mix"; core=core, rng=MersenneTwister(123))
    @test size(foam2) == (32, 32)
    @test length(objects2) == 6
    @test count(>(0), abs.(foam2)) > 0

    foam3, objects3 = TomoPhantom.foam3D(-0.7, 0.7, -0.7, 0.7, -0.7, 0.7, 0.2, 1.0, 0.05, 0.1, 16, 4, "mix"; core=core, rng=MersenneTwister(123))
    @test size(foam3) == (16, 16, 16)
    @test length(objects3) == 4
    @test count(>(0), abs.(foam3)) > 0
end

@testset "quality metrics" begin
    im1 = reshape(Float32.(1:25), 5, 5)
    im2 = copy(im1)
    im2[3, 3] += 2

    qt = TomoPhantom.QualityTools(im1, im2)
    @test TomoPhantom.rmse(qt) > 0
    @test TomoPhantom.nrmse(qt) < 1

    window = ones(Float32, 3, 3)
    mssim_same, ssim_map_same = TomoPhantom.ssim(im1, im1, window)
    @test mssim_same ≈ 1 atol=1e-5
    @test size(ssim_map_same) == (3, 3)

    mssim_diff, _ = TomoPhantom.ssim(im1, im2, window)
    @test mssim_diff < 1
end

@testset "sino3d_natural cone regression" begin
    core = TomoPhantom.NativeCore()
    model = TomoPhantom.LibraryModel(6, TomoPhantom.default_3d_library_path())
    geom = TomoPhantom.SinoGeom3D(32, 32, 32, collect(Float32, range(0.0f0, 177.0f0; length=16)), 0, 32)
    sino = TomoPhantom.sino3d_natural(core, model, geom)
    @test any(!iszero, sino)
end

@testset "temporal phantom2d" begin
    core = TomoPhantom.NativeCore()
    libpath = TomoPhantom.default_2d_library_path()

    for (model_id, frames) in ((100, 3), (101, 350), (102, 25))
        phantom = TomoPhantom.phantom2d(core, TomoPhantom.LibraryModel(model_id, libpath), 8)
        @test size(phantom) == (8, 8, frames)
        @test any(!iszero, phantom)
    end
end

@testset "temporal sino2d_natural" begin
    core = TomoPhantom.NativeCore()
    libpath = TomoPhantom.default_2d_library_path()
    geom = TomoPhantom.SinoGeom2D(8, 9, collect(Float32, range(0.0f0, 144.0f0; length=5)))

    for (model_id, frames) in ((100, 3), (101, 350), (102, 25))
        sino = TomoPhantom.sino2d_natural(core, TomoPhantom.LibraryModel(model_id, libpath), geom)
        @test size(sino) == (5, 9, frames)
        @test any(!iszero, sino)
    end
end

@testset "temporal phantom3d" begin
    core = TomoPhantom.NativeCore()
    libpath = TomoPhantom.default_3d_library_path()

    for (model_id, frames) in ((100, 5), (101, 10), (102, 10))
        phantom = TomoPhantom.phantom3d(core, TomoPhantom.LibraryModel(model_id, libpath), 8)
        @test size(phantom) == (8, 8, 8, frames)
        @test any(!iszero, phantom)
    end
end

@testset "temporal sino3d_natural" begin
    core = TomoPhantom.NativeCore()
    libpath = TomoPhantom.default_3d_library_path()
    geom = TomoPhantom.SinoGeom3D(8, 9, 8, collect(Float32, range(0.0f0, 144.0f0; length=5)), 0, 8)

    for (model_id, frames) in ((100, 5), (101, 10), (102, 10))
        sino = TomoPhantom.sino3d_natural(core, TomoPhantom.LibraryModel(model_id, libpath), geom)
        @test size(sino) == (9, 8, 5, frames)
        @test any(!iszero, sino)
    end
end
