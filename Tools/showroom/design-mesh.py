"""Closed authoring primitives for the project-owned ship recipes."""

import math


def add(a, b):
    return [a[i] + b[i] for i in range(3)]


def sub(a, b):
    return [a[i] - b[i] for i in range(3)]


def mul(a, scalar):
    return [x * scalar for x in a]


def dot(a, b):
    return sum(x * y for x, y in zip(a, b))


def cross(a, b):
    return [
        a[1] * b[2] - a[2] * b[1],
        a[2] * b[0] - a[0] * b[2],
        a[0] * b[1] - a[1] * b[0],
    ]


def unit(a):
    length = math.sqrt(dot(a, a))
    return mul(a, 1 / length) if length else [0, 0, 0]


class Builder:
    """Keep semantic component/face/material assignments with the actual mesh."""

    def __init__(self, palette):
        self.vertices, self.faces, self.assignments, self.components = [], [], [], []
        self.palette = palette
        self.names = {p["name"]: i for i, p in enumerate(palette)}

    def component(self, points, polygons, material="hull", name="hull", orient=True):
        offset, first = len(self.vertices), len(self.faces)
        center = [sum(p[i] for p in points) / len(points) for i in range(3)]
        self.vertices.extend(points)
        for face in polygons:
            polygon = list(face)
            a, b, c = [points[k] for k in polygon[:3]]
            normal = cross(sub(b, a), sub(c, a))
            middle = [
                sum(points[k][i] for k in polygon) / len(polygon) - center[i]
                for i in range(3)
            ]
            if orient and dot(normal, middle) < 0:
                polygon.reverse()
            self.faces.append([k + offset for k in polygon])
            self.assignments.append(self.names[material])
        self.components.append(
            {"name": name, "firstFace": first, "faceCount": len(polygons)}
        )

    def box(self, center, size, material="secondary", name="equipment", yaw=0):
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
                    center[0] + x * math.cos(yaw) - z * math.sin(yaw),
                    center[1] + y,
                    center[2] + x * math.sin(yaw) + z * math.cos(yaw),
                ]
            )
        self.component(
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

    def loft(
        self,
        rings,
        center=(0, 0),
        sections=8,
        material="hull",
        name="fuselage",
        phase=math.pi / 8,
    ):
        """Elliptical/chamfered cross sections along Z, preserving each slope."""
        points = [
            [
                center[0] + w * math.cos(phase + i * math.tau / sections),
                center[1] + h * math.sin(phase + i * math.tau / sections),
                z,
            ]
            for z, w, h in rings
            for i in range(sections)
        ]
        faces = [list(reversed(range(sections)))]
        for ring in range(len(rings) - 1):
            for i in range(sections):
                a, b = ring * sections + i, ring * sections + (i + 1) % sections
                # Unequal ellipse ratios make warped quads; two real triangles.
                faces.extend([[a, b, b + sections], [a, b + sections, a + sections]])
        faces.append(list(range((len(rings) - 1) * sections, len(rings) * sections)))
        self.component(points, faces, material, name, orient=False)

    def wing(self, outline, y=0, thickness=3, material="hull", name="wing"):
        """A closed planar-outline plate; clockwise or anticlockwise is accepted."""
        points = [
            [x, y + side * thickness / 2, z] for side in [-1, 1] for x, z in outline
        ]
        n = len(outline)
        faces = [list(reversed(range(n))), list(range(n, 2 * n))]
        faces += [[i, (i + 1) % n, (i + 1) % n + n, i + n] for i in range(n)]
        self.component(points, faces, material, name)

    def engine(self, x, y, z, radius=5, name="engine"):
        self.loft(
            [
                (z - 8, radius * 1.15, radius * 1.15),
                (z, radius, radius),
                (z + 3, radius * 0.75, radius * 0.75),
            ],
            (x, y),
            12,
            "dark",
            name + " housing",
            0,
        )
        self.loft(
            [
                (z + 3.1, radius * 0.65, radius * 0.65),
                (z + 3.3, radius * 0.65, radius * 0.65),
            ],
            (x, y),
            12,
            "engine",
            name + " nozzle",
            0,
        )

    def result(self, recipe):
        # Uniform scaling keeps authored silhouettes; stored envelope is a source
        # estimate, not permission to flatten every ship into the same aspect.
        spans = [
            max(p[i] for p in self.vertices) - min(p[i] for p in self.vertices)
            for i in range(3)
        ]
        centers = [
            (max(p[i] for p in self.vertices) + min(p[i] for p in self.vertices)) / 2
            for i in range(3)
        ]
        scale = max(recipe["dimensions"]) / max(spans)
        return {
            "vertices": [
                [round((p[i] - centers[i]) * scale, 5) for i in range(3)]
                for p in self.vertices
            ],
            "faces": self.faces,
            "materials": self.palette,
            "faceMaterials": self.assignments,
            "components": self.components,
            "source": "Right-On Commander original geometry",
            "license": "MIT",
            "paletteName": recipe["paletteName"],
            "appearanceSource": "Right-On Commander authored livery",
            "appearanceLicense": "MIT",
            "appearanceBasis": "Project adaptation; not a historical texture or manufacturer paint scheme",
        }
