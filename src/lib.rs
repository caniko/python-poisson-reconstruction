use ::poisson_reconstruction::{PoissonReconstruction, Real};
use numpy::{PyArray2, PyReadonlyArray2};
use pyo3::prelude::*;

use crate::helper::{vec_point3_to_pyarray, convert_pyarray2_to_vector3, convert_pyarray2_to_point3};

mod helper;

#[pyfunction]
#[pyo3(signature = (points, normals, screening=0.5, density_estimation_depth=9, max_depth=9, max_relaxation_iters=10))]
fn reconstruct_surface<'a>(
    py: Python<'a>,
    points: PyReadonlyArray2<Real>,
    normals: PyReadonlyArray2<Real>,
    screening: Real,
    density_estimation_depth: usize,
    max_depth: usize,
    max_relaxation_iters: usize,
) -> PyResult<&'a PyArray2<Real>> {
    if !points.is_contiguous() | !normals.is_contiguous() {
        panic!("The numpy arrays in this function must be contiguous")
    }
    let prepared_points = convert_pyarray2_to_point3(points);
    let prepared_normals = convert_pyarray2_to_vector3(normals);

    py.check_signals()?;

    dbg!("Running poisson.");
    let poisson = PoissonReconstruction::from_points_and_normals(
        &prepared_points,
        &prepared_normals,
        screening,
        density_estimation_depth,
        max_depth,
        max_relaxation_iters,
    );

    py.check_signals()?;

    dbg!("Extracting vertices.");
    let result = poisson.reconstruct_mesh();

    Ok(vec_point3_to_pyarray(py, result)?)
}

/// A Python module implemented in Rust.
#[pymodule]
fn poisson_reconstruction(_py: Python<'_>, m: &PyModule) -> PyResult<()> {
    m.add_function(wrap_pyfunction!(reconstruct_surface, m)?)?;
    Ok(())
}