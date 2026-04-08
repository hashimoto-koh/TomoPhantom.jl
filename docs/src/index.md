# TomoPhantom.jl

Welcome to the documentation for `TomoPhantom.jl`. This package is a Julia native binding layer for the [TomoPhantom](https://github.com/dkazanc/TomoPhantom) C core, widely used for generating phantoms and sinograms in tomographic imaging research.

## Features

This package exposes:
- **2D / 3D Model Phantoms**: Generate standard synthetic test models (such as Shepp-Logan).
- **2D / 3D Object Phantoms**: Generate shapes using parametric representations like ellipses, Gaussians, rectangles, etc.
- **Analytical Sinograms**: Create accurate 2D and 3D direct analytical projections (sinograms) ideal for mathematical testing and algorithmic validation.

## Documentation Outline

- **[Introduction](introduction.md)**: Learn about TomoPhantom and this Julia port.
- **[Installation Guide](installation.md)**: Instructions for adding the package and compiling dependencies.
- **Tutorials**: Get started quickly with practical examples for [2D Phantoms](tutorials/2d-phantom.md), [Models](tutorials/models.md) and [Projections](tutorials/projections.md).
- **API Reference**: Detailed breakdown of exported modules and functions including [Core Structures](api/core.md), [Generators](api/generators.md), and [Projections](api/projections.md).

Explore the sections via the sidebar to find what you need.
