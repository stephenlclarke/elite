"""Geometry regressions for family silhouettes and complete closed ship parts."""

import collections
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
author = load("mechanical-hulls")
PALETTE = [
    {"name": name}
    for name in ["hull", "secondary", "trim", "dark", "cockpit", "engine"]
]
VARIANTS = {
    "alliance": [2, 3, 4],
    "krait": [72, 73],
    "mandalay": [83],
    "viper": [137, 138, 139],
    "type6": [131],
    "type7": [132],
    "type8": [133],
    "type9": [134],
    "type10": [129],
    "type11": [130],
    "federal": [44, 45, 46, 47],
    "imperial": [62, 64],
    "liner": [12, 35, 93],
    "anaconda": [6],
    "cobra": [24, 25],
    "python": [100],
    "asp": [10, 11],
    "diamondback": [32, 33],
    "carrier": [43, 78, 79, 80, 81],
    "fighter": [
        41,
        42,
        54,
        56,
        59,
        65,
        69,
        70,
        85,
        94,
        103,
        110,
        111,
        140,
        145,
        146,
        147,
    ],
    "utility": [58, 68, 91],
    "freighter": [19, 74, 75, 97, 106],
    "wedge": [
        7,
        17,
        18,
        19,
        27,
        29,
        30,
        31,
        36,
        55,
        57,
        77,
        84,
        101,
        108,
        109,
        126,
        135,
        144,
    ],
}


def build(shape, variant):
    builder = mesh.Builder(PALETTE)
    assert author.build(builder, {"shape": shape, "variant": variant})
    return builder


def parts(builder, name):
    return [component for component in builder.components if component["name"] == name]


def points(builder, component):
    faces = builder.faces[
        component["firstFace"] : component["firstFace"] + component["faceCount"]
    ]
    return [
        builder.vertices[index] for index in {index for face in faces for index in face}
    ]


def spans(builder):
    return [
        max(p[i] for p in builder.vertices) - min(p[i] for p in builder.vertices)
        for i in range(3)
    ]


class MechanicalHullTests(unittest.TestCase):
    def test_all_families_have_closed_planar_outward_parts_and_complete_materials(self):
        for shape, variants in VARIANTS.items():
            for variant in variants:
                with self.subTest(shape=shape, variant=variant):
                    builder = build(shape, variant)
                    self.assertEqual(len(builder.faces), len(builder.assignments))
                    self.assertTrue(
                        all(0 <= index < len(PALETTE) for index in builder.assignments)
                    )
                    self.assertTrue(
                        all(
                            math.isfinite(value)
                            for p in builder.vertices
                            for value in p
                        )
                    )
                    # A missing cap or reversed side can disappear during ship rotation.
                    for component in builder.components:
                        faces = builder.faces[
                            component["firstFace"] : component["firstFace"]
                            + component["faceCount"]
                        ]
                        vertices = points(builder, component)
                        center = [
                            sum(p[i] for p in vertices) / len(vertices)
                            for i in range(3)
                        ]
                        edges = collections.Counter()
                        for face in faces:
                            self.assertGreaterEqual(len(face), 3)
                            self.assertEqual(len(face), len(set(face)))
                            for a, b in zip(face, face[1:] + face[:1]):
                                edges[tuple(sorted((a, b)))] += 1
                            polygon = [builder.vertices[index] for index in face]
                            normal = mesh.cross(
                                mesh.sub(polygon[1], polygon[0]),
                                mesh.sub(polygon[2], polygon[0]),
                            )
                            length = math.sqrt(mesh.dot(normal, normal))
                            self.assertGreater(length, 1e-6)
                            middle = [
                                sum(p[i] for p in polygon) / len(polygon)
                                for i in range(3)
                            ]
                            self.assertGreaterEqual(
                                mesh.dot(normal, mesh.sub(middle, center)), -1e-6
                            )
                            for point in polygon[3:]:
                                self.assertLess(
                                    abs(mesh.dot(normal, mesh.sub(point, polygon[0])))
                                    / length,
                                    1e-6,
                                )
                        self.assertTrue(
                            all(count == 2 for count in edges.values()),
                            component["name"],
                        )

    def test_krait_delta_viper_wedge_and_mandalay_gull_wings_remain_distinct(self):
        for variant in VARIANTS["krait"]:
            builder = build("krait", variant)
            self.assertEqual(len(parts(builder, "integral delta wing")), 2)
            width, _, length = spans(builder)
            self.assertGreater(width, length)
            self.assertFalse(parts(builder, "engine nacelle"))
        for variant in VARIANTS["viper"]:
            builder = build("viper", variant)
            width, _, length = spans(builder)
            self.assertLess(width, length * 0.55)
            self.assertEqual(len(parts(builder, "swept shoulder")), 2)
        mandalay = build("mandalay", 83)
        self.assertEqual(len(parts(mandalay, "gull wing root")), 2)
        self.assertEqual(len(parts(mandalay, "swept explorer wing")), 2)
        for part in parts(mandalay, "swept explorer wing"):
            wing = points(mandalay, part)
            self.assertGreater(min(p[2] for p in wing if abs(p[0]) > 90), 25)
        self.assertFalse(parts(mandalay, "integral delta wing"))

    def test_alliance_variants_have_different_drive_and_hangar_architectures(self):
        chieftain = build("alliance", 3)
        challenger = build("alliance", 2)
        crusader = build("alliance", 4)
        self.assertEqual(len(parts(chieftain, "forward engine arm")), 2)
        self.assertEqual(len(parts(chieftain, "aft engine arm")), 2)
        self.assertFalse(parts(challenger, "aft engine arm"))
        self.assertEqual(len(parts(challenger, "central engine nozzle")), 2)
        self.assertEqual(len(parts(crusader, "fighter hangar housing")), 1)
        self.assertFalse(parts(chieftain, "fighter hangar housing"))

    def test_industrial_types_keep_their_distinct_load_and_engine_bodies(self):
        identities = {6: 131, 7: 132, 8: 133, 9: 134, 10: 129, 11: 130}
        bodies = {
            model: build(f"type{model}", variant)
            for model, variant in identities.items()
        }
        self.assertGreater(spans(bodies[7])[1], spans(bodies[6])[1] * 1.35)
        self.assertEqual(len(parts(bodies[8], "Type-8 cargo outrigger")), 2)
        self.assertEqual(len(parts(bodies[9], "heavy cargo shoulder")), 2)
        self.assertFalse(parts(bodies[9], "Defender aft aerofoil"))
        self.assertEqual(len(parts(bodies[10], "Defender aft aerofoil")), 1)
        self.assertEqual(len(parts(bodies[11], "forward mining boom")), 2)
        self.assertEqual(len(parts(bodies[11], "mineral scoop aperture")), 1)
        self.assertEqual(
            len({repr(builder.vertices) for builder in bodies.values()}), 6
        )

    def test_unhandled_organic_shape_is_left_for_its_own_author(self):
        builder = mesh.Builder(PALETTE)
        self.assertFalse(author.build(builder, {"shape": "organic", "variant": 114}))
        self.assertEqual(builder.vertices, [])
        self.assertEqual(builder.faces, [])
        self.assertEqual(builder.components, [])


if __name__ == "__main__":
    unittest.main()
