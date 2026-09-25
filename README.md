# TomoPhantom.jl

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://hashimoto-koh.github.io/TomoPhantom.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://hashimoto-koh.github.io/TomoPhantom.jl/dev/)

`TomoPhantom.jl` is a Julia port of [TomoPhantom](https://github.com/dkazanc/TomoPhantom), the analytical phantom and sinogram generation project by Daniil Kazantsev and contributors.

This repository exists because the original `TomoPhantom` project is valuable, carefully designed, and widely useful in tomography research. The Julia port is developed with explicit respect for that work, and with sincere gratitude to the original authors for publishing and maintaining the upstream project.

## What This Repository Is

`TomoPhantom.jl` provides a Julia-first interface to the native `TomoPhantom` core for:

- 2D analytical phantoms from the upstream model libraries
- 3D analytical phantoms from the upstream model libraries
- 2D object-based phantom generation
- 3D object-based phantom generation
- 2D analytical sinograms
- 3D analytical projection data

The port is intentionally native and Julia-centric:

- no Python wrapper layer is used at runtime
- no `PyCall` / `PythonCall` dependency is required
- Julia calls the native `TomoPhantom` C entry points directly via `ccall`
- the upstream Python and MATLAB wrappers are explicitly disabled during build

## Upstream Policy

This repository does **not** vendor the original `TomoPhantom` source tree.

Instead, `deps/build.jl` fetches the required upstream C sources and phantom library `.dat` files at build time from pinned upstream revisions, applies the small local integration patches needed by the Julia port, and builds the shared library locally on your machine.

That policy keeps this repository focused on the Julia port itself while preserving a reproducible build story and a clear boundary between upstream source and Julia-side integration.

## Installation

### Installing from the public repository

If the package is not registered, install it directly from the repository URL:

```julia
using Pkg
Pkg.add(url="https://github.com/hashimoto-koh/TomoPhantom.jl.git")
Pkg.build("TomoPhantom")
```

The equivalent package REPL command is:

```julia
pkg> add https://github.com/hashimoto-koh/TomoPhantom.jl.git
pkg> build TomoPhantom
```

### Working from a local checkout

```julia
using Pkg
Pkg.develop(path="/path/to/TomoPhantom.jl")
Pkg.build("TomoPhantom")
```

### System requirements

Because `TomoPhantom.jl` builds the native library locally instead of relying on vendored upstream source or prebuilt JLL binaries, your system should provide:

- a C compiler such as `gcc` or `clang`
- `cmake`
- OpenMP support
- network access to fetch the pinned upstream source files during `Pkg.build("TomoPhantom")`

After build, the package can be loaded normally:

```julia
using TomoPhantom
```

## Quick Start

```julia
using TomoPhantom

core = NativeCore()
model = LibraryModel(1, default_2d_library_path())
phantom = phantom2d(core, model, 256)

angles = Float32.(range(0f0, 179f0; length = 180))
geom = SinoGeom2D(256, 360, angles)
sino = sino2d_natural(core, model, geom)
```

See the documentation for fuller tutorials and API details.

## Documentation

Full documentation is available here:

- [Stable Documentation](https://hashimoto-koh.github.io/TomoPhantom.jl/stable/)
- [Development Documentation](https://hashimoto-koh.github.io/TomoPhantom.jl/dev/)

The documentation covers installation, examples, API references, and background notes on the Julia port.

## Demos

Interactive Jupyter notebooks are provided in the [`demos/`](demos/) directory to explore workflows and visualize phantoms and projections using [CairoMakie.jl](https://github.com/MakieOrg/Makie.jl):

- **[`demo_2d.ipynb`](demos/demo_2d.ipynb)**: Complete 2D workflow covering all 15 stationary benchmark models, bespoke geometric objects (`object2d`), random cellular foam (`foam2D`), exact analytical sinograms (`sino2d_natural`), zero-cost transpose views (`sino2d_u_angle_view`), realistic acquisition artefacts (`artefacts_mix`), and quantitative benchmarking metrics (`rmse`, `ssim`).
- **[`demo_3d.ipynb`](demos/demo_3d.ipynb)**: Comprehensive 3D workflow including volumetric model rendering (`phantom3d`), orthogonal slice views (Axial, Coronal, Sagittal), 3D geometric primitives (`object3d`), porous 3D foam structures (`foam3D`), analytical 3D parallel-beam projections/radiographs (`sino3d_natural`), depth slice galleries, and 3D acquisition artefacts.
- **[`demo_temporal_4d.ipynb`](demos/demo_temporal_4d.ipynb)**: Time-evolving (temporal / dynamic) simulations including 2D+time phantoms and sinograms (Models 100, 101, 102) and 3D+time (4D CT) volumetric phantoms, illustrating physiological motion and dynamic processes across discrete time frames.
- **[`demo_flats_and_normalization.ipynb`](demos/demo_flats_and_normalization.ipynb)**: Physical flat-field synthesis (`synth_flats`) emulating non-uniform X-ray beam profiles, scintillator dust, detector pixel miscalibration (stripe/ring artifacts), Poisson photon noise, and mechanical jitter, accompanied by standard Beer-Lambert normalization preprocessing.

## License

This repository is distributed under the Apache License 2.0. For details, see [LICENSE](LICENSE).

Third-party attribution and upstream integration notes are collected in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

For the original project, documentation, and upstream implementation, see:

- upstream repository: <https://github.com/dkazanc/TomoPhantom>
- upstream documentation: <https://dkazanc.github.io/TomoPhantom/>
