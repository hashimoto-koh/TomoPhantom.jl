# About TomoPhantom Core

The [TomoPhantom](https://github.com/dkazanc/TomoPhantom) core library is an open-source software tool widely utilized in the imaging sciences for generating highly customizable phantom models and performing analytical projections.

## Why Ground Truth Matters

When developing, bench-testing, or validating tomographic image reconstruction algorithms, using **ground truth phantoms** is absolutely crucial. A common pitfall in inverse problem research is performing discrete forward projections on a digital object, adding noise, and then running a discrete inverse solver on that identical gridded model. This is known as an *inverse crime*, and it usually leads to falsely optimistic performance metrics. 

By delivering purely analytical integration algorithms over continuous parametric shapes, `TomoPhantom` lets you bypass the voxel grid for the forward step, guaranteeing that any blur or aliasing in the reconstructed result comes entirely from your solver, and not from numerical gridding errors.

## Key Capabilities

The C library specializes in three crucial tasks, all mapped 1:1 in this Julia wrapper:

### 1. Spatial Phantom Generation
Create complex synthetic objects rapidly in both 2D and 3D. Users can assemble custom objects using basic geometric building blocks recursively or select from standard models common in literature, such as variations of the Shepp-Logan phantom.

### 2. Analytical Sinogram Generation
Produce precise numerical sinograms from the analytical properties of defined shapes (like Gaussians, ellipses, or rectangles). Because these projections are calculated via path-length formulas rather than ray-tracing through a pixel grid, they provide mathematically perfect constraints avoiding rasterization bounds.

### 3. Algorithm Benchmarking Support
Thanks to the robust parametric definitions of objects (each element having known centroids, orientations, and scale factors), users can script extensive, reproducible benchmark suites. You can perturb features to test how well a regularization scheme preserves edges, or simulate continuous moving objects to validate 4D dynamic CT.

## 2D vs. 3D Modes

`TomoPhantom.jl` maps functionality strictly for standard 2D parallel/fan geometries and 3D geometries.
- **2D Operations**: Rely on the `SinoGeom2D` geometry constraints and construct projections onto line detectors evaluated across defined degrees.
- **3D Operations**: Utilize volumetric primitives like ellipsoids and cylinders via `SinoGeom3D`, projecting them systematically onto 2D planar detectors across arrays of angles.
