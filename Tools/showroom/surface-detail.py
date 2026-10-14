"""Shallow armour panel cells and bounded closed service structures.

Large flat faces receive a clipped rectilinear panel layout. Fine bevels remain
subordinate to the authored hull silhouette; glass, engines and organic skins
are never treated as mechanical armour.
"""

import importlib.util
import math
from pathlib import Path

_spec = importlib.util.spec_from_file_location(
    "design_mesh", Path(__file__).with_name("design-mesh.py")
)
mesh = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(mesh)


def cross2(a, b):
    return a[0] * b[1] - a[1] * b[0]


def area2(points):
    return abs(sum(cross2(a, b) for a, b in zip(points, points[1:] + points[:1]))) / 2


def simplify(points):
    """Remove clip-boundary duplicates and straight vertices before meshing."""
    result = []
    for point in points:
        if not result or math.dist(point, result[-1]) > 1e-7:
            result.append(point)
    if len(result) > 1 and math.dist(result[0], result[-1]) < 1e-7:
        result.pop()
    while len(result) >= 3:
        keep = []
        for index, point in enumerate(result):
            previous, following = result[index - 1], result[(index + 1) % len(result)]
            a = [point[i] - previous[i] for i in range(2)]
            b = [following[i] - point[i] for i in range(2)]
            if abs(cross2(a, b)) > 1e-7:
                keep.append(point)
        if len(keep) == len(result):
            # Put the strongest corner first: rounded TOML coordinates must not
            # derive a face normal from three almost collinear clipped points.
            # Equal corners (every triangle, rectangles and symmetric clips)
            # differ by a few ulps after plane projection. Quantize the ordering
            # key and break ties geometrically, preserving the actual points.
            # Otherwise Python's float-summation changes rotate stored vertices.
            def corner_key(index, polygon=result):
                strength = abs(
                    cross2(
                        [polygon[index][j] - polygon[index - 1][j] for j in range(2)],
                        [
                            polygon[(index + 1) % len(polygon)][j] - polygon[index][j]
                            for j in range(2)
                        ],
                    )
                )
                return (round(strength, 8), *(round(v, 8) for v in polygon[index]))

            corner = max(range(len(result)), key=corner_key)
            start = (corner - 1) % len(result)
            return result[start:] + result[:start]
        result = keep
    return []


def clip(points, axis, boundary, keep_greater):
    """Clip a convex surface polygon to one local grid boundary."""
    if not points:
        return []
    result = []
    previous = points[-1]
    previous_inside = (
        (previous[axis] >= boundary - 1e-8)
        if keep_greater
        else (previous[axis] <= boundary + 1e-8)
    )
    for point in points:
        inside = (
            (point[axis] >= boundary - 1e-8)
            if keep_greater
            else (point[axis] <= boundary + 1e-8)
        )
        if inside != previous_inside:
            fraction = (boundary - previous[axis]) / (point[axis] - previous[axis])
            result.append(
                [previous[i] + fraction * (point[i] - previous[i]) for i in range(2)]
            )
        if inside:
            result.append(point)
        previous, previous_inside = point, inside
    return simplify(result)


def frame(points):
    """A stable local face plane aligned to its longest authored edge."""
    normal = mesh.unit(
        mesh.cross(mesh.sub(points[1], points[0]), mesh.sub(points[2], points[0]))
    )
    center = [sum(p[i] for p in points) / len(points) for i in range(3)]
    longest = max(
        (mesh.sub(points[(i + 1) % len(points)], p) for i, p in enumerate(points)),
        key=lambda edge: mesh.dot(edge, edge),
    )
    u = mesh.unit(longest)
    v = mesh.unit(mesh.cross(normal, u))
    local = [
        [mesh.dot(mesh.sub(point, center), u), mesh.dot(mesh.sub(point, center), v)]
        for point in points
    ]
    return center, normal, u, v, local


def world(local, center, u, v, normal, depth=0):
    return mesh.add(
        mesh.add(mesh.add(center, mesh.mul(u, local[0])), mesh.mul(v, local[1])),
        mesh.mul(normal, depth),
    )


def cells(polygon):
    """Only broad flat plates are divided; narrow/small surfaces stay broad."""
    area = area2(polygon)
    low = [min(p[i] for p in polygon) for i in range(2)]
    high = [max(p[i] for p in polygon) for i in range(2)]
    span = [high[i] - low[i] for i in range(2)]
    if area < 400 or min(span) < 12:
        return [polygon]
    columns, rows = (3, 2) if area > 900 and span[0] > 36 else (2, 2)
    result = []
    for column in range(columns):
        for row in range(rows):
            bounds = [
                low[0] + span[0] * column / columns,
                low[0] + span[0] * (column + 1) / columns,
                low[1] + span[1] * row / rows,
                low[1] + span[1] * (row + 1) / rows,
            ]
            part = polygon
            for axis, boundary, greater in [
                (0, bounds[0], True),
                (0, bounds[1], False),
                (1, bounds[2], True),
                (1, bounds[3], False),
            ]:
                part = clip(part, axis, boundary, greater)
            if part and area2(part) > 1e-6:
                result.append(part)
    return result


def well(builder, polygon, plane, material):
    """Replace one surface cell by its narrow bevel and actual recessed floor."""
    center, normal, u, v = plane
    middle = [sum(p[i] for p in polygon) / len(polygon) for i in range(2)]
    inner = [
        [middle[i] + (point[i] - middle[i]) * 0.955 for i in range(2)]
        for point in polygon
    ]
    offset, count = len(builder.vertices), len(polygon)
    builder.vertices.extend(world(point, center, u, v, normal) for point in polygon)
    builder.vertices.extend(
        world(point, center, u, v, normal, -0.28) for point in inner
    )
    for index in range(count):
        following = (index + 1) % count
        builder.faces.append(
            [
                offset + index,
                offset + following,
                offset + count + following,
                offset + count + index,
            ]
        )
        builder.assignments.append(builder.names["secondary"])
    builder.faces.append(list(range(offset + count, offset + count * 2)))
    builder.assignments.append(material)


def flat_cell(builder, polygon, plane, material):
    center, normal, u, v = plane
    offset = len(builder.vertices)
    builder.vertices.extend(world(point, center, u, v, normal) for point in polygon)
    builder.faces.append(list(range(offset, offset + len(polygon))))
    builder.assignments.append(material)


def rectangle_fit(polygon, width=8.5, height=5.5):
    """Fit every corner within the parent face, including skinny triangles."""
    scale = 1.0
    for a, b in zip(polygon, polygon[1:] + polygon[:1]):
        edge = [b[i] - a[i] for i in range(2)]
        at_center = cross2(edge, [-a[0], -a[1]])
        for x, y in [
            (-width, -height),
            (width, -height),
            (width, height),
            (-width, height),
        ]:
            change = cross2(edge, [x, y])
            if change < -1e-9:
                scale = min(scale, at_center / -change)
    return width * scale * 0.78, height * scale * 0.78


def slab(builder, center, normal, u, v, width, height, bottom, top, material, name):
    rectangle = [[-width, -height], [width, -height], [width, height], [-width, height]]
    points = [
        world(point, center, u, v, normal, depth)
        for depth in [bottom, top]
        for point in rectangle
    ]
    builder.component(
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


def service_structures(builder, candidates, clean):
    """Closed bays sit in their surface; grille bars have a physical backing."""
    budget = 2 if clean else 6
    for index, (_, plane, polygon) in enumerate(
        sorted(candidates, key=lambda item: -item[0])[:budget]
    ):
        center, normal, u, v = plane
        width, height = rectangle_fit(polygon)
        if width < 1.8 or height < 1.2:
            continue
        # The backing intersects the recessed skin instead of floating above it.
        slab(
            builder,
            center,
            normal,
            u,
            v,
            width,
            height,
            -0.42,
            0.08,
            "dark",
            "recessed service bay",
        )
        if index == 1 or index == 4:
            slab(
                builder,
                center,
                normal,
                u,
                v,
                width * 0.88,
                height * 0.86,
                0.08,
                0.22,
                "secondary",
                "rectangular access panel",
            )
            for side in [-1, 1]:
                hinge = mesh.add(center, mesh.mul(u, side * width * 0.78))
                slab(
                    builder,
                    hinge,
                    normal,
                    u,
                    v,
                    width * 0.04,
                    height * 0.7,
                    0.22,
                    0.32,
                    "dark",
                    "access panel hinge",
                )
        else:
            for row in range(5):
                bar_center = mesh.add(center, mesh.mul(v, (row - 2) * height * 0.35))
                slab(
                    builder,
                    bar_center,
                    normal,
                    u,
                    v,
                    width * 0.88,
                    min(0.28, height * 0.065),
                    0.08,
                    0.43,
                    "secondary",
                    "vent grille",
                )


def detail(builder, recipe):
    """Replace eligible armour skins and keep semantic component boundaries."""
    if recipe["detailStyle"] == "organic":
        return 0
    old_faces, old_assignments, old_components = (
        builder.faces,
        builder.assignments,
        builder.components,
    )
    builder.faces, builder.assignments, builder.components = [], [], []
    panel_count, candidates = 0, []
    clean = recipe["detailStyle"] == "clean"
    for component in old_components:
        first = len(builder.faces)
        stop = component["firstFace"] + component["faceCount"]
        for index in range(component["firstFace"], stop):
            face, assignment = old_faces[index], old_assignments[index]
            material = builder.palette[assignment]["name"]
            points = [builder.vertices[k] for k in face]
            center, normal, u, v, polygon = frame(points)
            plane = center, normal, u, v
            area = area2(polygon)
            eligible = material in {"hull", "secondary"} and not (
                clean and material == "hull"
            )
            if not eligible or area < 90:
                builder.faces.append(face)
                builder.assignments.append(assignment)
                continue
            for cell in cells(polygon):
                if area2(cell) < 18:
                    flat_cell(builder, cell, plane, assignment)
                else:
                    # Strong accent trim belongs on chosen functional components,
                    # not every edge of every triangular authoring face.
                    well(builder, cell, plane, assignment)
                    panel_count += 1
            machinery = any(
                word in component["name"]
                for word in ["drive", "nacelle", "machinery", "service", "equipment"]
            )
            if (
                normal[1] > 0.55
                and area > 110
                and center[2] > -35
                and (not clean or machinery)
            ):
                candidates.append((area, plane, polygon))
        builder.components.append(
            {
                "name": component["name"],
                "firstFace": first,
                "faceCount": len(builder.faces) - first,
            }
        )
    service_structures(builder, candidates, clean)
    return panel_count
