"""Check actual clipped panel geometry and intentional clean-skin exclusions."""

import collections
import copy
import importlib.util
import math
import unittest
from pathlib import Path


def load(name):
    spec = importlib.util.spec_from_file_location(
        name, Path(__file__).with_name(name + ".py")
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


mesh = load("design-mesh")
surface = load("surface-detail")
PALETTE = [
    {"name": name}
    for name in ["hull", "secondary", "trim", "dark", "cockpit", "engine"]
]


def state(builder):
    return copy.deepcopy(
        (builder.vertices, builder.faces, builder.assignments, builder.components)
    )


def planar(test, builder):
    for face in builder.faces:
        points = [builder.vertices[index] for index in face]
        normal = mesh.cross(
            mesh.sub(points[1], points[0]), mesh.sub(points[2], points[0])
        )
        length = math.sqrt(mesh.dot(normal, normal))
        test.assertGreater(length, 1e-6)
        for point in points[3:]:
            test.assertLess(
                abs(mesh.dot(normal, mesh.sub(point, points[0]))) / length, 1e-6
            )


class SurfaceDetailTests(unittest.TestCase):
    def test_symmetric_corner_order_is_independent_of_input_start_and_float_noise(self):
        triangle = [
            [20.269862587448483, -7.627396677454265],
            [10.735957176051745, 15.254793354908529],
            [-31.005819763500234, -7.627396677454265],
        ]
        square = [[-40, -20], [40, -20], [40, 20], [-40, 20]]
        for polygon in (triangle, square):
            expected = surface.simplify(polygon)
            for shift in range(len(polygon)):
                rotated = polygon[shift:] + polygon[:shift]
                self.assertEqual(surface.simplify(rotated), expected)
                for noise in (-1e-11, 1e-11):
                    noisy = copy.deepcopy(rotated)
                    noisy[0][0] += noise
                    actual = surface.simplify(noisy)
                    self.assertEqual(
                        [[round(v, 8) for v in p] for p in actual],
                        [[round(v, 8) for v in p] for p in expected],
                    )
                    # Ordering normalization must not snap authored coordinates.
                    self.assertEqual(sorted(actual), sorted(noisy))

    def test_large_triangle_clipping_conserves_area_and_creates_rectilinear_cells(self):
        triangle = [[-50, -25], [50, -25], [-10, 50]]
        cells = surface.cells(triangle)
        self.assertGreaterEqual(len(cells), 4)
        self.assertLessEqual(len(cells), 6)
        self.assertGreaterEqual(sum(len(cell) == 4 for cell in cells), 2)
        self.assertAlmostEqual(
            sum(surface.area2(cell) for cell in cells), surface.area2(triangle)
        )
        for cell in cells:
            self.assertGreater(surface.area2(cell), 0)
            for point in cell:
                for a, b in zip(triangle, triangle[1:] + triangle[:1]):
                    self.assertGreaterEqual(
                        surface.cross2(
                            [b[i] - a[i] for i in range(2)],
                            [point[i] - a[i] for i in range(2)],
                        ),
                        -1e-7,
                    )
        small = [[-5, -4], [5, -4], [5, 4], [-5, 4]]
        self.assertEqual(surface.cells(small), [small])
        narrow = [[-60, -3], [60, -3], [60, 3], [-60, 3]]
        self.assertEqual(surface.cells(narrow), [narrow])

    def test_armour_has_real_shallow_recesses_and_no_accent_outline(self):
        builder = mesh.Builder(PALETTE)
        builder.box((0, 0, 0), (40, 20, 60), "hull", "armoured cabin")
        original_vertices = copy.deepcopy(builder.vertices)
        count = surface.detail(builder, {"detailStyle": "armour"})
        self.assertGreater(count, 12)
        self.assertEqual(builder.vertices[:8], original_vertices)
        self.assertNotIn(builder.names["trim"], builder.assignments)
        floors = [
            face
            for face, assignment in zip(builder.faces, builder.assignments)
            if assignment == builder.names["hull"]
            and all(abs(builder.vertices[index][1] - 9.72) < 1e-7 for index in face)
        ]
        self.assertGreaterEqual(len(floors), 4)
        self.assertTrue(any(len(face) == 4 for face in floors))
        planar(self, builder)

    def test_service_grilles_have_closed_backing_and_access_panels(self):
        builder = mesh.Builder(PALETTE)
        for x in [-25, 25]:
            builder.box((x, 0, 10), (30, 12, 48), "hull", "service deck")
        surface.detail(builder, {"detailStyle": "armour"})
        names = [component["name"] for component in builder.components]
        self.assertIn("vent grille", names)
        self.assertIn("recessed service bay", names)
        self.assertIn("rectangular access panel", names)
        for component in builder.components:
            if component["name"] == "service deck":
                continue
            edges = collections.Counter()
            faces = builder.faces[
                component["firstFace"] : component["firstFace"] + component["faceCount"]
            ]
            for face in faces:
                for a, b in zip(face, face[1:] + face[:1]):
                    edges[tuple(sorted((a, b)))] += 1
            self.assertTrue(
                all(count == 2 for count in edges.values()), component["name"]
            )
        planar(self, builder)

    def test_bounded_service_rectangle_fits_a_skinny_triangle(self):
        triangle = [[-40, -6], [40, -6], [0, 12]]
        width, height = surface.rectangle_fit(triangle)
        self.assertGreater(width, 0)
        self.assertGreater(height, 0)
        for point in [
            [-width, -height],
            [width, -height],
            [width, height],
            [-width, height],
        ]:
            for a, b in zip(triangle, triangle[1:] + triangle[:1]):
                self.assertGreaterEqual(
                    surface.cross2(
                        [b[i] - a[i] for i in range(2)],
                        [point[i] - a[i] for i in range(2)],
                    ),
                    0,
                )

    def test_clean_hull_and_organic_policy_preserve_original_geometry(self):
        for style, material in [("clean", "hull"), ("organic", "secondary")]:
            with self.subTest(style=style):
                builder = mesh.Builder(PALETTE)
                builder.box((0, 0, 0), (80, 30, 90), material, "smooth skin")
                original = state(builder)
                self.assertEqual(surface.detail(builder, {"detailStyle": style}), 0)
                self.assertEqual(state(builder), original)
        builder = mesh.Builder(PALETTE)
        builder.box((0, 0, 0), (80, 30, 90), "secondary", "engine nacelle")
        self.assertGreater(surface.detail(builder, {"detailStyle": "clean"}), 0)
        self.assertTrue(any(c["name"] == "vent grille" for c in builder.components))

    def test_glass_and_engine_faces_are_preserved(self):
        builder = mesh.Builder(PALETTE)
        builder.box((-50, 0, 0), (70, 30, 90), "cockpit", "canopy")
        builder.box((50, 0, 0), (70, 30, 90), "engine", "drive aperture")
        original = state(builder)
        self.assertEqual(surface.detail(builder, {"detailStyle": "armour"}), 0)
        self.assertEqual(state(builder), original)


if __name__ == "__main__":
    unittest.main()
