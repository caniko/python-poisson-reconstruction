from pathlib import Path

import open3d as o3d
import numpy as np

from poisson_reconstruction import reconstruct_surface


PATH_TO_PLY_POINT_CLOUD = Path(__file__).parent / "pc.ply"


def test_surface_reconstruction():
    pcd = o3d.io.read_point_cloud(str(PATH_TO_PLY_POINT_CLOUD))
    pcd.estimate_normals()
    pcd.orient_normals_consistent_tangent_plane(k=20)

    points, normals = np.ascontiguousarray(pcd.points), np.ascontiguousarray(pcd.normals)
    reconstruct_surface(points, normals, screening=0.0, density_estimation_depth=9, max_depth=9, max_relaxation_iters=10)
