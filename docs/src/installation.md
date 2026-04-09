# Installation Guide

`TomoPhantom.jl` is a Julia port of the original `TomoPhantom` project. It maps Julia arrays directly to the upstream native computations without relying on the upstream Python wrapper.

The Julia port is developed with respect for the original upstream repository and with gratitude to its authors and maintainers. This repository does **not** vendor the original `TomoPhantom` source tree; instead, the required native sources and phantom library data files are fetched during build from pinned upstream revisions.

While the Julia code itself is portable, installation requires compiling the native backend on your machine.

## Standard Installation

To install `TomoPhantom.jl`, open the Julia REPL and enter the `Pkg` mode by simply typing `]`:

```julia
pkg> add https://github.com/hashimoto-koh/TomoPhantom.jl.git
pkg> build TomoPhantom
```

Alternatively, invoke it directly within your scripts or notebooks using the `Pkg` API:

```julia
using Pkg
Pkg.add(url="https://github.com/hashimoto-koh/TomoPhantom.jl.git")
Pkg.build("TomoPhantom")
```

If you are working from a local checkout:

```julia
using Pkg
Pkg.develop(path="/path/to/TomoPhantom.jl")
Pkg.build("TomoPhantom")
```

## System Build Requirements

Because `TomoPhantom.jl` physically builds the native C library locally during the installation process (rather than relying on pre-built monolithic binaries distributed via JLLs), your system **must** have the following development tools installed prior to executing `Pkg.add`:

1. **A C Compiler**: e.g. `gcc` for Linux/Windows, or `clang` for macOS.
2. **CMake**: The build scripts utilize CMake to configure the library target. Make sure `cmake` is accessible in your generic environment `PATH`.
3. **OpenMP Support**: Advanced parallel computations inside TomoPhantom scale heavily based on OpenMP threading. 
   - **Linux**: Handled natively by GCC.
   - **macOS**: Often requires installing explicit OpenMP headers, achievable via Homebrew: `brew install libomp`.
4. **Network Access**: `Pkg.build("TomoPhantom")` fetches the pinned upstream source files and phantom library data files.

During `Pkg.build("TomoPhantom")`, Julia executes the internal build script `deps/build.jl`. This script fetches the required upstream C source files and `.dat` model libraries, applies the local integration changes for the Julia port, builds the library via CMake under `deps/build/`, and creates `libtomophantom`.

At runtime, `TomoPhantom.jl` loads that native library directly and calls its exported entry points via Julia `ccall`. No Python wrapper, `PyCall`, or `PythonCall` layer is used. The integration strategy is direct native C access, with the same non-Python-native approach intended for any lower-level accelerator or CUDA-facing integration.

## Testing the Installation

To verify that the library compiled perfectly and your Julia session can successfully communicate dynamically with the compiled binary, run the embedded self-check tool `demo_step2`:

```julia
using TomoPhantom
results = TomoPhantom.demo_step2()
```

If it executes without errors, the core C hooks are securely attached. `demo_step2` automatically outputs diagnostic properties about sizes, structural norms, and non-zero counts of expected test primitives.

## Advanced Usage: Overriding the C-Core Target

The build script defaults to fetching upstream core files from the primary `TomoPhantom` repository using a pinned commit hash to ensure highly reproducible builds locally and on Continuous Integration (CI) servers.

If you are developing custom patches to TomoPhantom or wish to ride on the absolute bleeding edge of the master branch, you can supply specific override environment variables during building:

```bash
# Example leveraging the main branch instead of the pinned commit
TOMOPHANTOM_UPSTREAM_REPO=dkazanc/TomoPhantom \
TOMOPHANTOM_UPSTREAM_REF=main \
julia --project -e 'using Pkg; Pkg.build("TomoPhantom")'
```
