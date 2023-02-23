use ::poisson_reconstruction::{PoissonReconstruction, Real};
use nalgebra::{Point3, Vector3};
use numpy::{ndarray::Array2, IntoPyArray, PyArray2};
use pyo3::prelude::*;

fn vec_point3_to_pyarray<'a>(
    py: Python<'a>,
    vec: Vec<Point3<Real>>,
) -> PyResult<&'a PyArray2<Real>> {
    let nrows = vec.len();
    let mut data: Vec<f64> = Vec::with_capacity(nrows * 3);

    for point in vec {
        data.push(point.x);
        data.push(point.y);
        data.push(point.z);
    }
    Ok(Array2::from_shape_vec((nrows, 3), data)
        .expect("Failed to convert result into array")
        .into_pyarray(py))
}

#[pyfunction]
#[pyo3(signature = (points, normals, screening=0.5, density_estimation_depth=9, max_depth=9, max_relaxation_iters=10))]
fn reconstruct_surface<'a>(
    py: Python<'a>,
    points: &PyArray2<Real>,
    normals: &PyArray2<Real>,
    screening: Real,
    density_estimation_depth: usize,
    max_depth: usize,
    max_relaxation_iters: usize,
) -> PyResult<&'a PyArray2<Real>> {
    if !points.is_contiguous() | !normals.is_c_contiguous() {
        panic!("The numpy arrays in this function must be contigious")
    }
    let prepared_points = Point3::from(Vector3::from_vec(points.to_vec()?));
    let prepared_normals = Vector3::from_vec(normals.to_vec()?);

    dbg!("Running poisson.");
    let poisson = PoissonReconstruction::from_points_and_normals(
        &[prepared_points],
        &[prepared_normals],
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