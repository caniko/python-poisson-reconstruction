# Poisson reconstruction vision

A small Python package that exposes Poisson surface reconstruction from point
clouds, implemented in Rust and shipped as a native extension. `reconstruct_surface`
takes an `(N, 3)` array of points and an `(N, 3)` array of normals and returns
mesh vertices, with the algorithm's tuning parameters — screening, density
estimation depth, max depth and relaxation iterations — available from Python.
It exists so point-cloud work in Python can use a Rust reconstruction
implementation without reimplementing the solver or shelling out to Open3D.

## Problem

Poisson reconstruction is available in Python only through larger binaries that
expose a narrow slice of the algorithm. The Rust crate behind this package
exposes more of the parameters, which matters when a reconstruction has to be
tuned rather than accepted at defaults. The cost of that access in Python is a
build boundary: a Rust `cdylib` built with maturin, pyo3 and numpy bindings,
with point/vector conversion between NumPy arrays and nalgebra types.

## Principles

- **Thin binding, no policy.** The extension converts arrays, calls the crate,
  and returns vertices. Tuning stays with the caller.
- **Fail loudly on incompatible input.** Arrays must be contiguous; the binding
  panics rather than silently copying or reshaping data the caller did not
  intend to transform.
- **Stay interruptible.** Python signal checks are placed around the long
  reconstruction step so a run can be cancelled.
- **Published and reproducible.** Versioned crates.io/PyPI packaging, a Nix flake
  and generated CI workflows qualify both surfaces.

## Scope

In scope: the `poisson_reconstruction` extension module, its array conversion
helpers, packaging for PyPI and crates.io, and a single integration test that
reconstructs a sample point cloud (`test/pc.ply`) using Open3D for normals.

## Non-goals

- Not a point-cloud pipeline: it does not load files, estimate or orient
  normals, decimate, or write meshes. The test uses Open3D for normals, which
  shows where the boundary sits.
- Not performance-competitive. The README states plainly that it is slow.

## Direction

The README's open thread is that no comparison against Open3D's Poisson
implementation has been made, and that this implementation exposes parameters
Open3D does not. Otherwise recent history is packaging and CI maintenance
(Simit-generated workflows, harbor-rs inputs) rather than algorithm work.
Direction: no roadmap documented beyond that comparison.

## Place in the fleet

Canix runs this repository as a Simit updater target on atlas, so its flake and
generated CI are refreshed with the rest of the fleet. No Canix host or service
depends on the package.
