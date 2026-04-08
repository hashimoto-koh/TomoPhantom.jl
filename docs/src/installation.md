# Installation Guide

`TomoPhantom.jl` is designed as a Julia wrapper mapping native multi-dimensional arrays directly to the original `TomoPhantom` C computations. While the Julia code itself is pure and platform-independent, it requires compiling the C backend securely on your machine.

## Standard Installation

To install `TomoPhantom.jl`, open the Julia REPL and enter the `Pkg` mode by simply typing `]`:

```julia
pkg> add https://github.com/hashimoto-koh/TomoPhantom.jl.git
```

Alternatively, invoke it directly within your scripts or notebooks using the `Pkg` API:

```julia
using Pkg
Pkg.add(url="https://github.com/hashimoto-koh/TomoPhantom.jl.git")
```

## System Build Requirements

Because `TomoPhantom.jl` physically builds the native C library locally during the installation process (rather than relying on pre-built monolithic binaries distributed via JLLs), your system **must** have the following development tools installed prior to executing `Pkg.add`:

1. **A C Compiler**: e.g. `gcc` for Linux/Windows, or `clang` for macOS.
2. **CMake**: The build scripts utilize CMake to configure the library target. Make sure `cmake` is accessible in your generic environment `PATH`.
3. **OpenMP Support**: Advanced parallel computations inside TomoPhantom scale heavily based on OpenMP threading. 
   - **Linux**: Handled natively by GCC.
   - **macOS**: Often requires installing explicit OpenMP headers, achievable via Homebrew: `brew install libomp`.

During `Pkg.build("TomoPhantom")`, Julia executes the internal build script `deps/build.jl`. This script automatically fetches the required upstream C source files, downloads the specific `.dat` library model definitions, builds the library via CMake under `deps/build/`, and creates `libtomophantom`.

## Testing the Installation

To verify that the library compiled perfectly and your Julia session can successfully communicate dynamically with the compiled binary, run the embedded self-check tool `demo_step2`:

```julia
using TomoPhantom
results = TomoPhantom.demo_step2()
```

If it executes without errors, the core C hooks are securely attached. `demo_step2` automatically outputs diagnostic properties about sizes, structural norms, and non-zero counts of expected test primitives.

## Advanced Usage: Overriding the C-Core Target

The build script defaults to cloning upstream core files from the primary `TomoPhantom` repository using a "pinned" commit hash to ensure highly reproducible builds locally and on Continuous Integration (CI) servers.

If you are developing custom patches to TomoPhantom or wish to ride on the absolute bleeding edge of the master branch, you can supply specific override environment variables during building:

```bash
# Example leveraging the main branch instead of the pinned commit
TOMOPHANTOM_UPSTREAM_REPO=dkazanc/TomoPhantom \
TOMOPHANTOM_UPSTREAM_REF=main \
julia --project -e 'using Pkg; Pkg.build("TomoPhantom")'
```
