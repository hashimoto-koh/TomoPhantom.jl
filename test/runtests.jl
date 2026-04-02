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
