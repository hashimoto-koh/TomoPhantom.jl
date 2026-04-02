# TomoPhantom.jl

`TomoPhantom.jl` is a Julia binding layer for the native TomoPhantom C implementation.

## Current scope

This package currently exposes:

- 2D model phantoms
- 3D model phantoms
- 2D object phantoms
- 3D object phantoms
- 2D analytical sinograms
- 3D analytical projection data

## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/hashimoto-koh/TomoPhantom.jl.git")
```

The current package build fetches the required upstream TomoPhantom source files and model-library files, then compiles the native C library with CMake during package installation.

## Semantics

This package currently returns native-order arrays:

- `phantom2d`: `A[x, y]`
- `phantom3d`: `A[x, y, z]`
- `sino2d_natural`: `S[angle, u]`
- `sino3d_natural`: `S[u, v, angle]`

If a consumer wants alternate axis order, use the provided no-copy adapters:

- `sino2d_u_angle_view`
- `sino3d_u_angle_v_view`

## Packaging note

This package is designed so the Julia repository can stay minimal.
Only Julia code, build logic, tests, and documentation need to live in the Julia package repository.
The upstream C sources and `.dat` model-library files are fetched at build time.

The default upstream ref is pinned to a specific commit for reproducibility. Override `TOMOPHANTOM_UPSTREAM_REF` only when you intentionally want a different upstream state.
