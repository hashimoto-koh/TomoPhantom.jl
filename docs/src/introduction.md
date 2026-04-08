# About TomoPhantom.jl

`TomoPhantom.jl` is the Julia implementation and binding layer for the original `TomoPhantom` C library.

## Purpose and Motivation

The primary motivation for this package is to allow Julia developers and researchers working in inverse problems, CT reconstruction, and image processing to quickly generate highly accurate analytical phantoms directly inside Julia.

While there are many pixel-driven or ray-driven projectors available across ecosystems, very few provide robust **analytical** projection tools. When validating a novel image reconstruction algorithm, using discrete projectors for both the "forward" step and the "backward" step can mask numerical inconsistencies (the "inverse crime"). `TomoPhantom.jl` solves this by delivering pure analytical solutions—the forward data (sinograms) is perfectly calculated from geometry equations, allowing strict evaluations of your reconstruction algorithms.

## Design Philosophy

This repository is kept intentionally minimal to maximize compatibility and reduce footprint. Rather than cloning all of the raw C code and maintaining two divergent bases, `TomoPhantom.jl` uses Julia's powerful package builder. It fetches the necessary C sources and precomputed library `.dat` models from the upstream target only when compiling the package, treating the C logic as a strictly managed dependency.

### C-Native Data Layouts

One crucial design point in this package is honoring the **C-core's memory layout** to ensure zero-cost abstractions out of the C library.

- **2D/3D Phantoms**: Emitted as `[x, y]` and `[x, y, z]` arrays.
- **Sinograms**: Produced natively as `[angle, detector]` for 2D, or `[detector_u, detector_v, angle]` for 3D. 

For many algorithms written natively in Julia or Python (like ASTRA), the expected angle order might be flipped. `TomoPhantom.jl` handles this elegantly via **no-copy axis adapters** (e.g. `sino2d_u_angle_view`), allowing you to transpose or permute views in `O(1)` time without duplicating massive geometric matrices in memory.

## Target Audience

This is designed for:
- Computed Tomography (CT) algorithm developers.
- Medical imaging researchers requiring ground-truth synthetic testing environments.
- High-performance computing groups optimizing projector matrices that need rigorous performance baselines.
