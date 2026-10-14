#!/usr/bin/env python3
"""Author the Liberator's three radial nacelles from its individual TOML recipe."""

import importlib.util
import math
from pathlib import Path


def design(recipe):
    """Use closed lofts and actual raised panels, with outward local winding."""
    vertices, faces, assignments = [], [], []
    palette = recipe["palette"]
    names = {material["name"]: index for index, material in enumerate(palette)}
    components = []

    def add(points, polygons, material, name):
        offset = len(vertices)
        first_face = len(faces)
        vertices.extend(points)
        faces.extend([[index + offset for index in polygon] for polygon in polygons])
        assignments.extend([names[material]] * len(polygons))
        components.append(
            {"name": name, "firstFace": first_face, "faceCount": len(polygons)}
        )

    def loft(rings, material, name, center=(0, 0), sections=12):
        # Theta increases around +Z. Side quads face radially out even at a neck.
        points = [
            [
                center[0] + radius * math.cos(i * math.tau / sections),
                center[1] + radius * math.sin(i * math.tau / sections),
                z,
            ]
            for z, radius in rings
            for i in range(sections)
        ]
        polygons = [list(reversed(range(sections)))]
        for ring in range(len(rings) - 1):
            for i in range(sections):
                a, b = ring * sections + i, ring * sections + (i + 1) % sections
                polygons.append([a, b, b + sections, a + sections])
        polygons.append(list(range((len(rings) - 1) * sections, len(rings) * sections)))
        add(points, polygons, material, name)

    def block(center, size, angle, material, name):
        points = []
        for x, y, z in [
            (-1, -1, -1),
            (1, -1, -1),
            (1, 1, -1),
            (-1, 1, -1),
            (-1, -1, 1),
            (1, -1, 1),
            (1, 1, 1),
            (-1, 1, 1),
        ]:
            x, y, z = x * size[0] / 2, y * size[1] / 2, z * size[2] / 2
            points.append(
                [
                    center[0] + x * math.cos(angle) - y * math.sin(angle),
                    center[1] + x * math.sin(angle) + y * math.cos(angle),
                    center[2] + z,
                ]
            )
        add(
            points,
            [
                [0, 3, 2, 1],
                [4, 5, 6, 7],
                [0, 1, 5, 4],
                [1, 2, 6, 5],
                [2, 3, 7, 6],
                [3, 0, 4, 7],
            ],
            material,
            name,
        )

    # Negative Z is the bow, including the long central probe and all three guns.
    loft(
        [
            (-146, 0.8),
            (-115, 3),
            (-99, 8),
            (-76, 11),
            (-58, 21),
            (-48, 25),
        ],
        "hull",
        "forward central hull",
    )
    # The collector replaces this hull section; an intersecting long grey tube
    # can be painter-sorted over the band when viewed obliquely.
    loft([(-12, 25), (31, 25), (48, 18), (55, 12)], "hull", "aft central hull")
    loft([(-48, 25.3), (-45, 26), (-15, 26), (-12, 25.3)], "gold", "collector band")
    for z in [-45, -12, 28]:
        loft([(z - 1, 26), (z + 1, 26)], "secondary", "central collar")
    # Collector strips are structured panels, rather than arbitrary triangulation.
    for angle_index in range(12):
        angle = angle_index * math.tau / 12
        for z in [-39, -30, -21]:
            block(
                (26.3 * math.cos(angle), 26.3 * math.sin(angle), z),
                (1.2, 10, 6),
                angle,
                "goldLight",
                "collector panel",
            )
    for angle_index in range(12):
        angle = angle_index * math.tau / 12
        for z in [0, 15]:
            block(
                (25.3 * math.cos(angle), 25.3 * math.sin(angle), z),
                (1.5, 7, 9),
                angle,
                "secondary",
                "central equipment panel",
            )
    for angle in [0, math.tau / 3, 2 * math.tau / 3]:
        block(
            (12 * math.cos(angle), 12 * math.sin(angle), -74),
            (3, 6, 8),
            angle,
            "oxide",
            "bow service block",
        )

    radius = recipe["nacelleRadius"]
    for nacelle in range(3):
        angle = math.pi / 2 + nacelle * math.tau / 3
        x, y = radius * math.cos(angle), radius * math.sin(angle)
        # Each swept arm is a closed, independently wound tapered prism.
        radial_points = [(16, 30), (radius - 5, -21), (radius + 3, -8), (19, 43)]
        points = [
            [
                r * math.cos(angle) - t * math.sin(angle),
                r * math.sin(angle) + t * math.cos(angle),
                z,
            ]
            for t in [-3, 3]
            for r, z in radial_points
        ]
        polygons = [
            [0, 3, 2, 1],
            [4, 5, 6, 7],
            [0, 1, 5, 4],
            [1, 2, 6, 5],
            [2, 3, 7, 6],
            [3, 0, 4, 7],
        ]
        center = [sum(p[i] for p in points) / 8 for i in range(3)]
        outward = []
        for polygon in polygons:
            a, b, c = [points[k] for k in polygon[:3]]
            ab, ac = [b[i] - a[i] for i in range(3)], [c[i] - a[i] for i in range(3)]
            normal = [
                ab[1] * ac[2] - ab[2] * ac[1],
                ab[2] * ac[0] - ab[0] * ac[2],
                ab[0] * ac[1] - ab[1] * ac[0],
            ]
            mid = [
                sum(points[k][i] for k in polygon) / len(polygon) - center[i]
                for i in range(3)
            ]
            outward.append(
                list(reversed(polygon))
                if sum(normal[i] * mid[i] for i in range(3)) < 0
                else polygon
            )
        add(points, outward, "hull", f"pylon {nacelle + 1}")
        for t in [0.3, 0.48, 0.66, 0.84]:
            r, z = 19 + t * (radius - 20), 37 - t * 51
            block(
                (r * math.cos(angle), r * math.sin(angle), z),
                (8, 7.2, 4),
                angle,
                "secondary",
                "pylon panel",
            )
        loft(
            [
                (-157, 0.65),
                (-128, 1.2),
                (-117, 6),
                (-102, 9),
                (-88, 19),
                (-66, 19),
                (-53, 12),
                (-42, 13),
                (3, 13),
                (7, 15),
                (23, 15),
                (27, 12),
            ],
            "hull",
            f"nacelle {nacelle + 1}",
            (x, y),
        )
        for z, r in [
            (-99, 10),
            (-88, 19.2),
            (-65, 19.2),
            (-44, 13.4),
            (4, 15.2),
            (21, 15.2),
        ]:
            loft([(z - 1, r), (z + 1, r)], "secondary", "nacelle collar", (x, y))
        # Six recessed-looking dark equipment bays and raised pale grille slats.
        for panel in range(6):
            a = panel * math.tau / 6
            block(
                (x + 18.7 * math.cos(a), y + 18.7 * math.sin(a), -76),
                (1.5, 10, 13),
                a,
                "dark",
                "nacelle bay",
            )
            for z in [-81, -77, -73]:
                block(
                    (x + 19.6 * math.cos(a), y + 19.6 * math.sin(a), z),
                    (1.1, 9, 1.5),
                    a,
                    "hull",
                    "bay grille",
                )
            block(
                (x + 13.1 * math.cos(a), y + 13.1 * math.sin(a), -20),
                (1.1, 4, 13),
                a,
                "secondary",
                "nacelle rear panel",
            )

    # Two green domes meet a SINGLE horizontal pale housing, independent of
    # the three-fold nacelle symmetry. Every green vertex lies on the sphere.
    center_z, engine_radius = 82, recipe["engineRadius"]
    band_half_width = recipe["engineBandHalfWidth"]
    latitude_start = math.asin(band_half_width / engine_radius)
    latitude_end = math.pi / 2 - 0.01

    def rotate_to_y(first_vertex):
        for point in vertices[first_vertex:]:
            point[1], point[2] = point[2], center_z - point[1]

    for sign, name in [(1, "upper engine dome"), (-1, "lower engine dome")]:
        rings = [
            (sign * engine_radius * math.sin(a), engine_radius * math.cos(a))
            for a in [
                latitude_start + i * (latitude_end - latitude_start) / 10
                for i in range(11)
            ]
        ]
        first_vertex = len(vertices)
        loft(sorted(rings), "engine", name, sections=32)
        rotate_to_y(first_vertex)
    first_vertex = len(vertices)
    rim_radius = math.sqrt(engine_radius**2 - band_half_width**2) + 1
    loft(
        [
            (-band_half_width, rim_radius),
            (0, engine_radius + 1),
            (band_half_width, rim_radius),
        ],
        "hull",
        "equatorial engine housing",
        sections=32,
    )
    rotate_to_y(first_vertex)

    # Pale fine ribs are conforming spherical surface strips, never green fins.
    for offset in [-0.82, -0.61, -0.40, -0.19, 0.02, 0.23, 0.44, 0.65, 0.86]:
        for sign in [-1, 1]:
            points = []
            for z in [offset * engine_radius - 0.28, offset * engine_radius + 0.28]:
                radius = math.sqrt((engine_radius + 0.12) ** 2 - z * z)
                start_angle = math.asin((band_half_width + 0.3) / radius)
                for i in range(17):
                    angle = start_angle + i * (math.pi - 2 * start_angle) / 16
                    points.append(
                        [
                            radius * math.cos(angle),
                            sign * radius * math.sin(angle),
                            center_z + z,
                        ]
                    )
            polygons = []
            for i in range(16):
                for polygon in [[i, i + 1, i + 18], [i, i + 18, i + 17]]:
                    a, b, c = [points[k] for k in polygon]
                    ab, ac = (
                        [b[k] - a[k] for k in range(3)],
                        [c[k] - a[k] for k in range(3)],
                    )
                    normal = [
                        ab[1] * ac[2] - ab[2] * ac[1],
                        ab[2] * ac[0] - ab[0] * ac[2],
                        ab[0] * ac[1] - ab[1] * ac[0],
                    ]
                    radial = [a[0], a[1], a[2] - center_z]
                    polygons.append(
                        list(reversed(polygon))
                        if sum(normal[k] * radial[k] for k in range(3)) < 0
                        else polygon
                    )
            add(points, polygons, "hull", "fine engine rib")
    add(
        [
            [-14, -4, center_z + engine_radius - 6],
            [14, -4, center_z + engine_radius - 6],
            [14, 4, center_z + engine_radius - 6],
            [-14, 4, center_z + engine_radius - 6],
            [-0.5, -0.5, center_z + engine_radius + 14],
            [0.5, -0.5, center_z + engine_radius + 14],
            [0.5, 0.5, center_z + engine_radius + 14],
            [-0.5, 0.5, center_z + engine_radius + 14],
        ],
        [
            [0, 3, 2, 1],
            [4, 5, 6, 7],
            [0, 1, 5, 4],
            [1, 2, 6, 5],
            [2, 3, 7, 6],
            [3, 0, 4, 7],
        ],
        "hull",
        "aft pale housing point",
    )
    scale = recipe["length"] / (
        max(p[2] for p in vertices) - min(p[2] for p in vertices)
    )
    vertices = [[round(value * scale, 5) for value in point] for point in vertices]
    return {
        "vertices": vertices,
        "faces": faces,
        "source": "Right-On Commander Liberator interpretation; visual references in docs/LIBERATOR.md",
        "license": "MIT",
        "materials": palette,
        "faceMaterials": assignments,
        "paletteName": "liberator-pale-gold-green",
        "appearanceSource": "Right-On Commander authored Liberator livery; docs/LIBERATOR.md",
        "appearanceLicense": "MIT",
        "appearanceBasis": "Project interpretation of visual references; no imported textures",
        "recipe": recipe,
        "components": components,
    }


def main():
    """Rebuild geometry only; gameplay remains authoritative in the same TOML."""
    spec = importlib.util.spec_from_file_location(
        "ship_files", Path(__file__).with_name("ship-files.py")
    )
    files = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(files)
    ship = next(ship for ship in files.read_ships() if ship["id"] == "SH171")
    ship["design"] = design(ship["design"]["recipe"])
    ship["dimensions"] = [
        round(
            max(p[i] for p in ship["design"]["vertices"])
            - min(p[i] for p in ship["design"]["vertices"]),
            5,
        )
        for i in range(3)
    ]
    files.write_ship(files.SHIP_FOLDER / "SH171.toml", ship)


if __name__ == "__main__":
    main()
