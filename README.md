# TomoPhantom.jl

Julia bindings for the native TomoPhantom C core.

This package keeps the Julia repository minimal. During `Pkg.build`, it fetches the required upstream C sources and model-library files from the upstream TomoPhantom repository, builds the native library locally, and exposes a Julia-native API for:

- 2D model phantoms
- 3D model phantoms
- 2D object phantoms
- 3D object phantoms
- 2D analytical sinograms
- 3D analytical projection data

## Install from GitHub

From Julia:

```julia
using Pkg
Pkg.add(url="https://github.com/hashimoto-koh/TomoPhantom.jl.git")
```

Current build requirements:

- `cmake`
- a C compiler toolchain
- OpenMP support

The build step does all of the following via `deps/build.jl`:

- fetches the required C sources from upstream TomoPhantom
- fetches `Phantom2DLibrary.dat` and `Phantom3DLibrary.dat`
- compiles the native `libtomophantom` library locally with CMake

## Axis policy

This package currently uses the natural C memory semantics validated during the binding work:

- 2D phantom: `A[x, y]`
- 3D phantom: `A[x, y, z]`
- 2D sinogram: `S[angle, u]`
- 3D projection data: `S[u, v, angle]`

No-copy axis adapters are provided for consumers that want alternate views.

## Upstream tracking

By default, the build fetches upstream files from `dkazanc/TomoPhantom` pinned to commit `b75287a9706750951f8194902346ad91f7129064`.

You can override that at build time:

```bash
TOMOPHANTOM_UPSTREAM_REPO=dkazanc/TomoPhantom \
TOMOPHANTOM_UPSTREAM_REF=b75287a9706750951f8194902346ad91f7129064 \
julia --project -e 'using Pkg; Pkg.build("TomoPhantom")'
```

The default is intentionally pinned for reproducibility. Override `TOMOPHANTOM_UPSTREAM_REF` only when you intentionally want to track a newer upstream tag, branch, or commit.

## License

The upstream repository is licensed under Apache-2.0. The Julia package should remain Apache-2.0 as a derivative binding layer over the upstream implementation.
