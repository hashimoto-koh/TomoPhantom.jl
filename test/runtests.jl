using Test
using TomoPhantom

@testset "TomoPhantom.jl" begin
    result = TomoPhantom.selfcheck_step2()
    @test all(values(result.checks))
    @test result.shapes.phantom2d == (64, 64)
    @test result.shapes.sino2d_natural == (60, 91)
    @test result.shapes.phantom3d == (32, 32, 32)
    @test result.shapes.sino3d_natural == (96, 64, 45)
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
