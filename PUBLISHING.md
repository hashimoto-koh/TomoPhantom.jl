# Publishing Plan For TomoPhantom.jl

## Current state

This package is ready for Git-based installation with:

```julia
using Pkg
Pkg.add(url="https://github.com/hashimoto-koh/TomoPhantom.jl.git")
```

The package currently relies on:

- `deps/build.jl` fetching the required upstream C sources and `.dat` files
- local CMake compilation during package build

## Recommended release path

### Phase 1: GitHub URL install

Use a minimal Julia package repository and publish it for `Pkg.add(url=...)`.
This is enough for Git-based installation and keeps Julia-side maintenance decoupled from the full upstream tree.

### Phase 2: CI and docs

Add GitHub Actions for:

- `Pkg.build`
- `Pkg.test`
- `docs/make.jl`

Publish docs with Documenter.jl and GitHub Pages.
The current `docs/make.jl` is configured for the standalone `TomoPhantom.jl` repository.

### Phase 3: Registry-quality packaging

If you want plain `Pkg.add("TomoPhantom")`, you should publish the Julia package in its own repository named `TomoPhantom.jl` and register it.
You will also want to:

- decide whether to keep fetching upstream build inputs at build time or move to a pinned artifact strategy
- consider a binary distribution strategy instead of local CMake builds
- register the package in Julia General

## Binary distribution recommendation

The current build strategy requires local tools (`cmake`, compiler, OpenMP) and network access during `Pkg.build`.
For the easiest user install, the better long-term path is:

- package native binaries with BinaryBuilder.jl / JLL
- have the Julia package depend on the JLL artifact
- avoid per-user local compilation during `Pkg.add`

## License recommendation

The upstream repository is Apache-2.0.
The safest choice is to keep the Julia package Apache-2.0 too.

Why:

- the Julia bindings are a derivative integration layer over Apache-2.0 code
- the model-library files and native implementation come from the same upstream project
- keeping Apache-2.0 avoids unnecessary license friction

If you later split `TomoPhantom.jl` into a separate repository, include:

- `LICENSE` with Apache-2.0 text
- attribution to upstream TomoPhantom
- notices for copied or adapted files

## Important tradeoff

Fetching upstream build inputs at package-build time keeps the Julia repository minimal and makes upstream tracking easy.
But it also means builds are not fully hermetic unless you pin `TOMOPHANTOM_UPSTREAM_REF` to a specific tag or commit.

Recommended public-release default:

- keep the repo minimal
- document the required build tools clearly
- default to a pinned upstream commit or tag
- allow an environment variable override for advanced users
