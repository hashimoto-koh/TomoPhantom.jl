# Third-Party Notices

This repository, `TomoPhantom.jl`, is distributed under the Apache License 2.0. See [LICENSE](LICENSE).

## Upstream Project

`TomoPhantom.jl` is a Julia port of the upstream `TomoPhantom` project:

- upstream repository: <https://github.com/dkazanc/TomoPhantom>
- upstream documentation: <https://dkazanc.github.io/TomoPhantom/>
- upstream copyright: Copyright (c) 2017, The University of Manchester
- upstream license: Apache License 2.0

The maintainers of this repository gratefully acknowledge the work of Daniil Kazantsev and all contributors to the original `TomoPhantom` project.

## How This Repository Uses Upstream Material

This repository does not vendor the full upstream `TomoPhantom` source tree.

Instead, during `Pkg.build("TomoPhantom")`, the build script fetches selected upstream source files and phantom library data files from pinned upstream revisions, applies local integration patches where needed, and builds the native library locally.

The Julia package then interfaces with the resulting native library directly from Julia via native bindings, without relying on the upstream Python wrapper.

## Attribution and Redistribution Notes

This repository is intended to comply with the Apache License 2.0 obligations applicable to upstream-derived material, including preservation of relevant copyright and attribution notices.

If you redistribute this repository or derivative works of it, review:

- [LICENSE](LICENSE)
- [README.md](README.md)
- [deps/build.jl](deps/build.jl)

and ensure that any applicable upstream attribution and license obligations continue to be satisfied.
