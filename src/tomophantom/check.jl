_has_nonzero(A) = any(!iszero, A)

function _stats(A)
    vmax, imax = findmax(A)
    return (size=size(A), max=vmax, argmax=imax, nonzero=count(!iszero, A))
end

function demo_step2(; libpath::AbstractString=find_tomophantom_library())
    core = NativeCore(libpath)
    model2d = LibraryModel(1, default_2d_library_path())
    model3d = LibraryModel(1, default_3d_library_path())
    geom2d = SinoGeom2D(64, 91, collect(Float32, range(0.0f0, 177.0f0; length=60)))
    geom3d = SinoGeom3D(64, 96, 64, collect(Float32, range(0.0f0, 177.0f0; length=45)), 0, 64)

    A2_model = phantom2d(core, model2d, 64)
    A2_obj = object2d(core, 64, ObjectSpec2D(object="gaussian", x0=0.25f0, y0=-0.3f0, a=0.15f0, b=0.3f0, phi_rot=-30.0f0))
    S2 = sino2d_natural(core, model2d, geom2d)
    S2_obj = object_sino2d_natural(core, geom2d, ObjectSpec2D(object="gaussian", x0=0.1f0, y0=-0.1f0, a=0.2f0, b=0.2f0))
    A3_model = phantom3d(core, model3d, 32)
    A3_obj = object3d(core, 32, ObjectSpec3D(object="ellipsoid", a=0.3f0, b=0.2f0, c=0.2f0))
    S3 = sino3d_natural(core, model3d, geom3d)
    S3_obj = object_sino3d_natural(core, geom3d, ObjectSpec3D(object="ellipsoid", a=0.3f0, b=0.2f0, c=0.2f0))

    checks = (
        phantom2d_nonzero = _has_nonzero(A2_model),
        object2d_nonzero = _has_nonzero(A2_obj),
        sino2d_nonzero = _has_nonzero(S2),
        object_sino2d_nonzero = _has_nonzero(S2_obj),
        phantom3d_nonzero = _has_nonzero(A3_model),
        object3d_nonzero = _has_nonzero(A3_obj),
        sino3d_nonzero = _has_nonzero(S3),
        object_sino3d_nonzero = _has_nonzero(S3_obj),
    )
    all(values(checks)) || error("demo_step2 failed one or more non-zero checks: $(checks)")

    return (
        checks = checks,
        shapes = (
            phantom2d = size(A2_model),
            object2d = size(A2_obj),
            sino2d_natural = size(S2),
            object_sino2d_natural = size(S2_obj),
            phantom3d = size(A3_model),
            object3d = size(A3_obj),
            sino3d_natural = size(S3),
            object_sino3d_natural = size(S3_obj),
            sino2d_u_angle_view = size(sino2d_u_angle_view(S2)),
            sino3d_u_angle_v_view = size(sino3d_u_angle_v_view(S3)),
        ),
        maxima = (
            phantom2d = maximum(A2_model),
            object2d = maximum(A2_obj),
            sino2d = maximum(S2),
            object_sino2d = maximum(S2_obj),
            phantom3d = maximum(A3_model),
            object3d = maximum(A3_obj),
            sino3d = maximum(S3),
            object_sino3d = maximum(S3_obj),
        ),
        stats = (
            phantom2d = _stats(A2_model),
            object2d = _stats(A2_obj),
            sino2d_natural = _stats(S2),
            object_sino2d_natural = _stats(S2_obj),
            phantom3d = _stats(A3_model),
            object3d = _stats(A3_obj),
            sino3d_natural = _stats(S3),
            object_sino3d_natural = _stats(S3_obj),
        ),
    )
end

function selfcheck_step2(; libpath::AbstractString=find_tomophantom_library())
    result = demo_step2(; libpath=libpath)
    @assert all(values(result.checks))
    @assert result.shapes.phantom2d == (64, 64)
    @assert result.shapes.object2d == (64, 64)
    @assert result.shapes.sino2d_natural == (60, 91)
    @assert result.shapes.object_sino2d_natural == (60, 91)
    @assert result.shapes.phantom3d == (32, 32, 32)
    @assert result.shapes.object3d == (32, 32, 32)
    @assert result.shapes.sino3d_natural == (96, 64, 45)
    @assert result.shapes.object_sino3d_natural == (96, 64, 45)
    @assert result.shapes.sino2d_u_angle_view == (91, 60)
    @assert result.shapes.sino3d_u_angle_v_view == (96, 45, 64)
    @assert result.stats.phantom2d.nonzero > 0
    @assert result.stats.object2d.nonzero > 0
    @assert result.stats.sino2d_natural.nonzero > 0
    @assert result.stats.object_sino2d_natural.nonzero > 0
    @assert result.stats.phantom3d.nonzero > 0
    @assert result.stats.object3d.nonzero > 0
    @assert result.stats.sino3d_natural.nonzero > 0
    @assert result.stats.object_sino3d_natural.nonzero > 0
    return result
end
