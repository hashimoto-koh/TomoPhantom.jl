# TomoPhantom.jl Demos & Tutorials

This directory contains interactive Jupyter notebooks (`.ipynb`) demonstrating the core capabilities of **`TomoPhantom.jl`**, including analytical phantom design, 2D/3D sinogram simulation, realistic imaging physics (flat-fields and detector artefacts), and time-resolved (4D) dynamic tomography.

---

## Notebooks Overview

| Notebook | Description | Key Features |
| :--- | :--- | :--- |
| **[`demo_2d.ipynb`](./demo_2d.ipynb)** | **2D Phantoms & Sinograms** | Standard 2D benchmark models (Shepp-Logan, Defrise, etc.), custom geometric primitives (`object2d`), random cellular foam generation (`foam2D`), analytical Radon transforms (`sino2d_natural`), noise & artefacts, and SSIM metrics. |
| **[`demo_3d.ipynb`](./demo_3d.ipynb)** | **3D Volumetric Phantoms & Projections** | 3D volumetric model rendering, multi-planar orthogonal slicing (Axial, Coronal, Sagittal), 3D foam generation (`foam3D`), parallel/cone-beam forward projections (`sino3d_natural`), and projection galleries. |
| **[`demo_flats_and_normalization.ipynb`](./demo_flats_and_normalization.ipynb)** | **Flat-Field Synthesis & Normalization** | Simulating synchrotron/laboratory X-ray illumination effects (Bessel beam profile, scintillator speckles, detector sensitivity defects), Poisson/Gaussian noise, and Beer-Lambert logarithmic flat-field correction. |
| **[`demo_temporal_4d.ipynb`](./demo_temporal_4d.ipynb)** | **Temporal / Dynamic Tomography (2D+Time & 4D)** | Simulating physiological motion (cardiac/respiratory cycles) and dynamic material processes using time-dependent analytical models (Models 100, 101, 102) for dynamic CT benchmarking. |

---

## Prerequisites

The notebooks use **`CairoMakie`** for high-quality static visualizations and plots.

If `CairoMakie` is not installed in your current Julia environment, install it via:

```julia
using Pkg
Pkg.add("CairoMakie")
```

---

## How to Run

You can open and execute these notebooks using any standard Jupyter environment:

### Option 1: VS Code (Recommended)
1. Install the official **Julia** and **Jupyter** extensions in VS Code.
2. Open any `.ipynb` file in this directory and select your preferred Julia kernel.

### Option 2: JupyterLab / Jupyter Notebook
Launch Jupyter from your terminal:
```bash
jupyter lab demos/
```
or
```bash
jupyter notebook demos/
```
