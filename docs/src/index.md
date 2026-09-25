# TomoPhantom.jl

Welcome to the documentation for `TomoPhantom.jl`. This repository is a Julia port of the original [TomoPhantom](https://github.com/dkazanc/TomoPhantom) project and provides a Julia-native interface to its analytical phantom and projection core.

The Julia port is developed with explicit respect for the upstream work by Daniil Kazantsev and contributors, and with sincere gratitude for the original project and documentation.

## Features

This package exposes:
- **2D / 3D Model Phantoms**: Generate standard synthetic test models (such as Shepp-Logan).
- **2D / 3D Object Phantoms**: Generate shapes using parametric representations like ellipses, Gaussians, rectangles, etc.
- **2D / 3D Foam Generators**: Generate random foam-like phantoms from many non-overlapping primitive objects.
- **Analytical Sinograms**: Create accurate 2D and 3D direct analytical projections (sinograms) ideal for mathematical testing and algorithmic validation.
- **Artefact Synthesis**: Add zingers, stripes, shifts, noise, PVE, and Fresnel propagation effects to simulated data.
- **Quality Metrics**: Compare images or volumes using RMSE, NRMSE, and SSIM.

## Repository Policy

`TomoPhantom.jl` does **not** vendor the upstream `TomoPhantom` source tree in this repository.

Instead, the build step fetches the pinned upstream C sources and phantom library data files, applies local integration patches where needed, and compiles the shared library locally. The runtime interface is Julia-first and does not depend on the upstream Python wrapper.

## Documentation Outline

- **[Introduction](introduction.md)**: Learn about TomoPhantom and this Julia port.
- **[Installation Guide](installation.md)**: Instructions for adding the package and compiling dependencies.
- **Tutorials**: Get started quickly with practical examples for [2D Phantoms](tutorials/2d-phantom.md), [Models](tutorials/models.md), [Projections](tutorials/projections.md), and [Flat-field Synthesis](tutorials/flat-fields.md).
- **API Reference**: Detailed breakdown of exported modules and functions including [Core Structures](api/core.md), [Generators](api/generators.md), [Projections](api/projections.md), [Artefacts](api/artefacts.md), [Flat-field Synthesis](api/flatsgen.md), and [Quality Metrics](api/qualitymetrics.md).

Explore the sections via the sidebar to find what you need.
