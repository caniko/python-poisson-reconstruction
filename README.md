# Poisson surface reconstruction in Python

<!-- simit:badges:start -->

[![CI](https://img.shields.io/badge/CI-managed+extra-2088ff)](.github/workflows/ci.yaml) [![Nix](https://img.shields.io/badge/Nix-drift-5277c3)](flake.nix) [![crates.io](https://img.shields.io/badge/crates.io-ready-f46623)](https://crates.io/crates/poisson-reconstruction)

<!-- simit:badges:end -->

Small Python package with bindings for [poisson reconstruction](https://github.com/ForesightMiningSoftwareCorporation/PoissonReconstruction) written in Rust!

## Install
```shell
pip install poisson-reconstruction
```

## Usage
```python
import numpy as np
import poisson_reconstruction

points: np.NDArray = np.array([1, 2, 3], [1, 1, 1], ...)
normals: np.NDArray = np.array([0, 1, 0], [1, 0, 0], ...)

poisson_reconstruction.reconstruct_surface(points, normals, screening=0.5, density_estimation_depth=9, max_depth=9, max_relaxation_iters=10)
```

## Considerations
It is slow.

The [Open3D implementation](http://www.open3d.org/docs/latest/tutorial/Advanced/surface_reconstruction.html#Poisson-surface-reconstruction) only exposes the max-depth parameter, while the Rust implementation exposes even more. No comparisons between the two algorithms yet.