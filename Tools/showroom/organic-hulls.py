"""Smooth project-authored Thargoids; no imported model or texture geometry.

The scout's continuous, scalloped saucer follows the organic design language
shown by Frontier concept artist Emilie Rinna (ArtStation Pxx5L). Interceptors,
hunters and the Titan are deliberately distinct native adaptations. Sampling
follows the curvature; these ships do not receive mechanical panel processing.
"""

import math
from typing import Any

Point = list[float]

# These anatomical choices are authored interpretations, not historical data.
INTERCEPTORS = {
    112: {"radius": 105, "width": 18, "height": 7, "curl": 0.29, "lift": 11, "hub": 29},
    114: {"radius": 98, "width": 21, "height": 8, "curl": 0.12, "lift": 7, "hub": 27},
    116: {"radius": 112, "width": 14, "height": 8, "curl": 0.42, "lift": 16, "hub": 31},
    119: {"radius": 103, "width": 24, "height": 9, "curl": 0.35, "lift": 11, "hub": 34},
    120: {"radius": 89, "width": 20, "height": 12, "curl": -0.23, "lift": 3, "hub": 40},
}

SCOUTS = {
    113: {"radius": 88, "height": 19, "scallop": 0.06, "twist": 0.04, "hub": 26},
    117: {"radius": 90, "height": 16, "scallop": 0.10, "twist": 0.14, "hub": 32},
    118: {"radius": 102, "height": 12, "scallop": 0.035, "twist": -0.05, "hub": 21},
    121: {"radius": 84, "height": 25, "scallop": 0.13, "twist": -0.10, "hub": 36},
}


def _closed_component(
    builder: Any, points: list[Point], faces: list[list[int]], material: str, name: str
) -> None:
    """Orient the entire closed surface coherently, even on concave lobes."""
    volume = 0.0
    for face in faces:
        a, b, c = [points[index] for index in face]
        volume += (
            a[0] * (b[1] * c[2] - b[2] * c[1])
            + a[1] * (b[2] * c[0] - b[0] * c[2])
            + a[2] * (b[0] * c[1] - b[1] * c[0])
        )
    if volume < 0:
        faces = [list(reversed(face)) for face in faces]
    builder.component(points, faces, material, name, orient=False)


def _ring_surface(
    builder: Any,
    rings: list[list[Point]],
    first: Point,
    last: Point,
    material: str,
    name: str,
) -> None:
    """Close a curved surface with single poles, avoiding collapsed pole rings."""
    sections = len(rings[0])
    points = [first] + [point for ring in rings for point in ring] + [last]
    faces = [[0, 1 + (index + 1) % sections, 1 + index] for index in range(sections)]
    for row in range(len(rings) - 1):
        start = 1 + row * sections
        for index in range(sections):
            a, b = start + index, start + (index + 1) % sections
            faces.extend([[a, b, b + sections], [a, b + sections, a + sections]])
    start = 1 + (len(rings) - 1) * sections
    faces.extend(
        [start + index, start + (index + 1) % sections, len(points) - 1]
        for index in range(sections)
    )
    _closed_component(builder, points, faces, material, name)


def _body(
    builder: Any,
    center: tuple[float, float, float],
    radii: tuple[float, float, float],
    material: str,
    name: str,
    sections: int = 24,
    latitudes: int = 8,
    lobes: int = 0,
    scallop: float = 0.0,
    twist: float = 0.0,
) -> None:
    """Continuous ellipsoid/saucer with soft organic rim and radial folds."""
    rings = []
    for row in range(1, latitudes):
        latitude = math.pi * row / latitudes
        sine, cosine = math.sin(latitude), math.cos(latitude)
        ring = []
        for index in range(sections):
            angle = math.tau * index / sections
            wave = math.cos(lobes * (angle + twist * cosine)) if lobes else 0
            radius = sine * (1 + scallop * wave * sine**3)
            ring.append(
                [
                    center[0] + radii[0] * radius * math.cos(angle),
                    center[1]
                    + radii[1] * cosine * (1 + scallop * 0.8 * wave * sine**2),
                    center[2] + radii[2] * radius * math.sin(angle),
                ]
            )
        rings.append(ring)
    first = [center[0], center[1] + radii[1], center[2]]
    last = [center[0], center[1] - radii[1], center[2]]
    _ring_surface(builder, rings, first, last, material, name)


def _petal(
    builder: Any,
    angle: float,
    root: float,
    radius: float,
    width: float,
    height: float,
    curl: float,
    lift: float,
    material: str,
    name: str,
    levels: int = 9,
    sections: int = 10,
    y: float = 0,
) -> None:
    """Closed curved lobe, with rounded elliptical sections and two real poles."""

    def center(progress: float) -> Point:
        direction = angle + curl * progress**2
        distance = root + (radius - root) * progress
        return [
            distance * math.sin(direction),
            y + lift * math.sin(progress * math.pi / 2),
            -distance * math.cos(direction),
        ]

    rings = []
    for level in range(1, levels):
        latitude = math.pi * level / levels
        progress = (1 - math.cos(latitude)) / 2
        direction = angle + curl * progress**2
        position = center(progress)
        # A round bud at the end rather than a cone or a mechanical wing tip.
        envelope = math.sin(latitude) * (1 - 0.3 * progress)
        ring = []
        for index in range(sections):
            around = math.tau * index / sections
            lateral = width * envelope * math.cos(around)
            ring.append(
                [
                    position[0] + lateral * math.cos(direction),
                    position[1] + height * envelope * math.sin(around),
                    position[2] + lateral * math.sin(direction),
                ]
            )
        rings.append(ring)
    _ring_surface(builder, rings, center(0), center(1), material, name)


def _nodes(
    builder: Any,
    count: int,
    radius: float,
    y: float,
    scale: float = 3.2,
    phase: float = 0.0,
) -> None:
    """Small rounded bioluminescent organs; no antennae, grilles or metal seams."""
    for index in range(count):
        angle = phase + index * math.tau / count
        _body(
            builder,
            (radius * math.sin(angle), y, -radius * math.cos(angle)),
            (scale, scale * 0.55, scale),
            "engine",
            f"bioluminescent organ {index + 1}",
            sections=8,
            latitudes=4,
        )


def _interceptor(builder: Any, recipe: dict[str, Any], identity: int) -> None:
    anatomy = INTERCEPTORS[identity]
    petals = int(recipe.get("petals", recipe.get("lobes", 8)))
    for index in range(petals):
        _petal(
            builder,
            index * math.tau / petals,
            16,
            anatomy["radius"],
            anatomy["width"],
            anatomy["height"],
            anatomy["curl"],
            anatomy["lift"],
            "hull",
            f"curved interceptor lobe {index + 1}",
        )
    hub = anatomy["hub"]
    _body(builder, (0, 0, 0), (hub, 17, hub), "secondary", "interceptor core")
    _body(
        builder,
        (0, 15, 0),
        (10, 4, 10),
        "engine",
        "central luminous organ",
        sections=16,
        latitudes=5,
    )
    _nodes(builder, petals, hub * 0.72, 14, phase=anatomy["curl"] * 0.2)


def _scout(builder: Any, recipe: dict[str, Any], identity: int) -> None:
    anatomy = SCOUTS[identity]
    lobes = int(recipe.get("lobes", 8))
    _body(
        builder,
        (0, 0, 0),
        (anatomy["radius"], anatomy["height"], anatomy["radius"]),
        "hull",
        "continuous scout membrane",
        sections=64,
        latitudes=9,
        lobes=lobes,
        scallop=anatomy["scallop"],
        twist=anatomy["twist"],
    )
    # Distinct upper and lower hubs emerge through, rather than sit above, skin.
    _body(
        builder,
        (0, 3, 0),
        (anatomy["hub"], anatomy["height"] * 1.14, anatomy["hub"]),
        "secondary",
        "scout sensory core",
        sections=24,
        latitudes=7,
    )
    _nodes(
        builder, 6 if identity == 121 else 4, anatomy["hub"] * 0.7, anatomy["height"]
    )


def _hunter(builder: Any, identity: int) -> None:
    scythe = identity == 122
    _body(
        builder,
        (0, 0, 5),
        (22 if scythe else 27, 15, 61),
        "secondary",
        "hunter carapace",
        sections=24,
        latitudes=10,
        lobes=4,
        scallop=0.05,
    )
    # Bilateral hooked lobes make hunters recognisable from the radial fleet.
    for side in (-1, 1):
        for outer in (False, True):
            angle = side * (0.65 if outer else 0.24)
            _petal(
                builder,
                angle,
                8 if outer else 24,
                111 if scythe else 98,
                (17 if scythe else 23) if outer else 12,
                8,
                -side * (0.5 if scythe else 0.33),
                7 if outer else -4,
                "hull",
                f"{'port' if side < 0 else 'starboard'} {'outer' if outer else 'inner'} hunter lobe",
                levels=10,
                sections=12,
            )
    _body(
        builder,
        (0, 12, -28),
        (8, 4, 13),
        "engine",
        "hunter sensory organ",
        sections=16,
        latitudes=6,
    )
    _nodes(builder, 2, 12, -12, scale=4)


def _titan(builder: Any, recipe: dict[str, Any]) -> None:
    lobes = int(recipe.get("lobes", 8))
    _body(
        builder,
        (0, 0, 0),
        (79, 31, 79),
        "hull",
        "layered Titan membrane",
        sections=64,
        latitudes=8,
        lobes=lobes,
        scallop=0.17,
        twist=0.10,
    )
    for index in range(lobes):
        angle = index * math.tau / lobes
        _petal(
            builder,
            angle,
            27,
            126,
            28,
            12,
            0.18,
            2,
            "hull",
            f"Titan outer lobe {index + 1}",
            levels=6,
            sections=8,
        )
        _petal(
            builder,
            angle + math.pi / lobes,
            24,
            93,
            20,
            12,
            -0.15,
            -8,
            "secondary",
            f"Titan lower lobe {index + 1}",
            levels=5,
            sections=8,
            y=-12,
        )
    _body(
        builder,
        (0, 12, 0),
        (36, 28, 36),
        "secondary",
        "Titan central crown",
        sections=16,
        latitudes=6,
    )
    _body(
        builder,
        (0, 37, 0),
        (13, 6, 13),
        "engine",
        "Titan luminous core",
        sections=12,
        latitudes=4,
    )


def build(builder: Any, recipe: dict[str, Any]) -> bool:
    """Handle authored organic recipes; leave all other design shapes alone."""
    if recipe.get("shape") != "organic":
        return False
    identity = int(recipe["variant"])
    if identity in INTERCEPTORS:
        _interceptor(builder, recipe, identity)
    elif identity in SCOUTS:
        _scout(builder, recipe, identity)
    elif identity in (115, 122):
        _hunter(builder, identity)
    elif identity == 123:
        _titan(builder, recipe)
    else:
        return False
    return True
