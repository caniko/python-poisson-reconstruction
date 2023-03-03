use ::poisson_reconstruction::Real;
use nalgebra::{Point3, Vector3};
use numpy::{ndarray::Array2, IntoPyArray, PyArray2, PyReadonlyArray2};
use pyo3::prelude::*;

pub fn vec_point3_to_pyarray<'a>(
    py: Python<'a>,
    vec: Vec<Point3<Real>>,
) -> PyResult<&'a PyArray2<Real>> {
    let nrows = vec.len();
    let mut data: Vec<Real> = Vec::with_capacity(nrows * 3);

    for point in vec {
        data.push(point.x);
        data.push(point.y);
        data.push(point.z);
    }

    Ok(Array2::from_shape_vec((nrows, 3), data)
        .expect("Failed to convert result into array")
        .into_pyarray(py))
}

pub fn convert_pyarray2_to_vector3(py_array: PyReadonlyArray2<Real>) -> Vec<Vector3<Real>> {
    let arr = py_array.as_array();
    let num_rows = py_array.shape()[0];
    let mut vec = Vec::with_capacity(num_rows);
    for i in 0..num_rows {
        let vector = Vector3::new(arr[[i, 0]], arr[[i, 1]], arr[[i, 2]]);
        vec.push(vector);
    }
    vec
}

pub fn convert_pyarray2_to_point3(py_array: PyReadonlyArray2<Real>) -> Vec<Point3<Real>> {
    let arr = py_array.as_array();
    let num_rows = py_array.shape()[0];
    let mut vec = Vec::with_capacity(num_rows);
    for i in 0..num_rows {
        let vector = Point3::new(arr[[i, 0]], arr[[i, 1]], arr[[i, 2]]);
        vec.push(vector);
    }
    vec
}
