"""Structural checks for the reference-driven three-nacelle Liberator."""

import importlib.util
import math
import tomllib
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location(
    "liberator_design", Path(__file__).with_name("liberator-design.py")
)
author = importlib.util.module_from_spec(spec)
spec.loader.exec_module(author)


class LiberatorDesignTests(unittest.TestCase):
    def setUp(self):
        self.ship = tomllib.loads(
            Path("Sources/L337Core/Resources/Ships/SH171.toml").read_text()
        )
        self.design = self.ship["design"]

    def points(self, name):
        component = next(c for c in self.design["components"] if c["name"] == name)
        faces = self.design["faces"][
            component["firstFace"] : component["firstFace"] + component["faceCount"]
        ]
        return [
            self.design["vertices"][index]
            for index in {index for face in faces for index in face}
        ]

    def test_three_radial_nacelles_with_forward_points_and_aft_engine(self):
        centers = []
        for index in range(1, 4):
            points = self.points(f"nacelle {index}")
            centers.append(
                [sum(p[axis] for p in points) / len(points) for axis in [0, 1]]
            )
            self.assertLess(min(p[2] for p in points), -150)
            pylon = self.points(f"pylon {index}")
            self.assertGreater(max(math.hypot(p[0], p[1]) for p in pylon), 80)
            self.assertLess(min(math.hypot(p[0], p[1]) for p in pylon), 25)
        for a, b in zip(centers, centers[1:] + centers[:1]):
            cosine = sum(x * y for x, y in zip(a, b)) / (
                math.hypot(*a) * math.hypot(*b)
            )
            self.assertAlmostEqual(cosine, -0.5, places=5)
        engine = self.points("upper engine dome") + self.points("lower engine dome")
        self.assertGreater(min(p[2] for p in engine), 40)
        self.assertGreater(max(p[2] for p in engine), 120)
        self.assertEqual(
            sum(
                c["name"].startswith("nacelle ") and c["name"][-1].isdigit()
                for c in self.design["components"]
            ),
            3,
        )

    def test_engine_has_two_spherical_domes_one_band_and_no_green_spikes(self):
        scale = self.design["recipe"]["length"] / 293
        center = 82 * scale
        radius = self.design["recipe"]["engineRadius"] * scale
        band = self.design["recipe"]["engineBandHalfWidth"] * scale
        for name, sign in [("upper engine dome", 1), ("lower engine dome", -1)]:
            for x, y, z in self.points(name):
                self.assertAlmostEqual(
                    math.sqrt(x * x + y * y + (z - center) ** 2), radius, places=4
                )
                self.assertGreaterEqual(sign * y, band - 1e-4)
        components = self.design["components"]
        self.assertEqual(
            sum(c["name"] == "equatorial engine housing" for c in components), 1
        )
        self.assertFalse(any(c["name"] == "engine cradle" for c in components))
        for component in components:
            indices = self.design["faceMaterials"][
                component["firstFace"] : component["firstFace"] + component["faceCount"]
            ]
            if component["name"] not in ["upper engine dome", "lower engine dome"]:
                self.assertTrue(
                    all(
                        self.design["materials"][i]["name"] != "engine" for i in indices
                    )
                )
        point = self.points("aft pale housing point")
        self.assertGreater(max(p[2] for p in point), center + radius + 10 * scale)
        self.assertLess(max(abs(p[1]) for p in point), band)
        for c in components:
            if c["name"] == "fine engine rib":
                faces = self.design["faces"][
                    c["firstFace"] : c["firstFace"] + c["faceCount"]
                ]
                for index in {index for face in faces for index in face}:
                    x, y, z = self.design["vertices"][index]
                    self.assertLess(
                        math.sqrt(x * x + y * y + (z - center) ** 2),
                        radius + 0.15 * scale,
                    )

    def test_regeneration_materials_and_non_degenerate_planar_faces(self):
        self.assertEqual(author.design(self.design["recipe"]), self.design)
        self.assertEqual(len(self.design["faceMaterials"]), len(self.design["faces"]))
        self.assertLess(len(self.design["faces"]), 3500)
        self.assertEqual(
            {m["name"] for m in self.design["materials"] if m["emissive"]}, {"engine"}
        )
        for face in self.design["faces"]:
            points = [self.design["vertices"][i] for i in face]
            a, b, c = points[:3]
            ab, ac = [b[i] - a[i] for i in range(3)], [c[i] - a[i] for i in range(3)]
            normal = [
                ab[1] * ac[2] - ab[2] * ac[1],
                ab[2] * ac[0] - ab[0] * ac[2],
                ab[0] * ac[1] - ab[1] * ac[0],
            ]
            length = math.sqrt(sum(x * x for x in normal))
            self.assertGreater(length, 1e-6)
            for point in points[3:]:
                self.assertLess(
                    abs(sum(normal[i] * (point[i] - a[i]) for i in range(3))) / length,
                    1e-4,
                )

    def test_gold_collector_replaces_intersecting_grey_hull_section(self):
        scale = self.design["recipe"]["length"] / 293
        front, rear = -48 * scale, -12 * scale
        for name in ["forward central hull", "aft central hull"]:
            component = next(c for c in self.design["components"] if c["name"] == name)
            for face in self.design["faces"][
                component["firstFace"] : component["firstFace"] + component["faceCount"]
            ]:
                z = [self.design["vertices"][i][2] for i in face]
                self.assertTrue(max(z) <= front + 1e-4 or min(z) >= rear - 1e-4)
        band = self.points("collector band")
        self.assertLessEqual(min(p[2] for p in band), front + 1e-4)
        self.assertGreaterEqual(max(p[2] for p in band), rear - 1e-4)
        for quadrant in [(1, 1), (-1, 1), (-1, -1), (1, -1)]:
            self.assertTrue(
                any(p[0] * quadrant[0] > 10 and p[1] * quadrant[1] > 10 for p in band)
            )


if __name__ == "__main__":
    unittest.main()
