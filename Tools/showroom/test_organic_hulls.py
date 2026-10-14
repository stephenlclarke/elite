"""Geometry checks for the deliberately smooth, project-authored Thargoids."""

import importlib.util
import math
import unittest
from collections import Counter
from pathlib import Path


def load(name):
    spec = importlib.util.spec_from_file_location(
        name.replace("-", "_"), Path(__file__).with_name(f"{name}.py")
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


author = load("organic-hulls")
mesh = load("design-mesh")
PALETTE = [
    {"name": name, "colour": 0x45694FFF, "emissive": name == "engine"}
    for name in ("hull", "secondary", "trim", "dark", "cockpit", "engine")
]


class OrganicHullTests(unittest.TestCase):
    def make_ship(self, identity, **options):
        builder = mesh.Builder(PALETTE)
        recipe = dict(shape="organic", variant=identity, **options)
        self.assertTrue(author.build(builder, recipe))
        return builder

    def test_all_authored_organics_are_finite_closed_and_coherently_outward(self):
        for identity in range(112, 124):
            with self.subTest(ship=identity):
                builder = self.make_ship(identity)
                self.assertLess(len(builder.faces), 2500)
                self.assertEqual(len(builder.assignments), len(builder.faces))
                self.assertTrue(
                    all(math.isfinite(v) for p in builder.vertices for v in p)
                )
                for component in builder.components:
                    start = component["firstFace"]
                    faces = builder.faces[start : start + component["faceCount"]]
                    edges, directed = Counter(), Counter()
                    volume = 0.0
                    for face in faces:
                        self.assertEqual(len(face), 3)
                        self.assertEqual(len(set(face)), 3)
                        a, b, c = [builder.vertices[index] for index in face]
                        normal = mesh.cross(mesh.sub(b, a), mesh.sub(c, a))
                        self.assertGreater(mesh.dot(normal, normal), 1e-8)
                        volume += mesh.dot(a, mesh.cross(b, c)) / 6
                        for first, second in zip(face, face[1:] + face[:1]):
                            edges[tuple(sorted((first, second)))] += 1
                            directed[(first, second)] += 1
                    self.assertTrue(all(count == 2 for count in edges.values()))
                    for first, second in directed:
                        self.assertEqual(
                            directed[(first, second)], directed[(second, first)]
                        )
                    self.assertGreater(volume, 0)

    def test_repeatable_anatomy_and_distinct_forms_without_mechanical_parts(self):
        signatures = set()
        for identity in range(112, 124):
            a, b = self.make_ship(identity), self.make_ship(identity)
            self.assertEqual(a.vertices, b.vertices)
            self.assertEqual(a.faces, b.faces)
            signatures.add(tuple(tuple(p) for p in a.vertices))
            names = [component["name"] for component in a.components]
            self.assertFalse(
                any(
                    word in name
                    for name in names
                    for word in ("panel", "grille", "hardpoint", "cockpit", "nozzle")
                )
            )
            if identity in author.INTERCEPTORS:
                self.assertEqual(sum("interceptor lobe" in name for name in names), 8)
            elif identity in author.SCOUTS:
                self.assertIn("continuous scout membrane", names)
            elif identity in (115, 122):
                self.assertEqual(sum("hunter lobe" in name for name in names), 4)
            else:
                self.assertEqual(sum("Titan outer lobe" in name for name in names), 8)
                self.assertEqual(sum("Titan lower lobe" in name for name in names), 8)
        self.assertEqual(len(signatures), 12)

    def test_curved_lobes_and_unbroken_scout_skin(self):
        ship = self.make_ship(116)
        component = ship.components[0]
        faces = ship.faces[: component["faceCount"]]
        points = [ship.vertices[i] for i in {i for f in faces for i in f}]
        # A smooth, bent centerline and varying ellipse replace flat triangular arms.
        radii = sorted({round(math.hypot(p[0], p[2]), 3) for p in points})
        self.assertGreater(len(radii), 20)
        self.assertGreater(len({round(p[1], 3) for p in points}), 20)
        self.assertGreater(max(p[0] for p in points), 40)
        self.assertLess(max(p[0] for p in points), 60)
        scout = self.make_ship(117)
        membrane = scout.components[0]
        self.assertEqual(membrane["name"], "continuous scout membrane")
        self.assertEqual(membrane["faceCount"], 1024)
        self.assertGreater(max(p[1] for p in scout.vertices), 17)

    def test_optional_lobe_counts_and_unhandled_shapes(self):
        interceptor = self.make_ship(114, petals=6)
        self.assertEqual(
            sum("interceptor lobe" in c["name"] for c in interceptor.components), 6
        )
        titan = self.make_ship(123, lobes=6)
        self.assertEqual(
            sum("Titan outer lobe" in c["name"] for c in titan.components), 6
        )
        builder = mesh.Builder(PALETTE)
        self.assertFalse(author.build(builder, {"shape": "fighter", "variant": 114}))
        self.assertFalse(author.build(builder, {"shape": "organic", "variant": 111}))
        self.assertEqual(builder.vertices, [])


if __name__ == "__main__":
    unittest.main()
