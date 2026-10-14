"""Design-appropriate project hull revision; recipes and final meshes live in TOMLs."""

import importlib.util
from pathlib import Path


def module(name):
    spec = importlib.util.spec_from_file_location(
        name, Path(__file__).with_name(name + ".py")
    )
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


mesh = module("design-mesh")
mechanical = module("mechanical-hulls")
organic = module("organic-hulls")
surface = module("surface-detail")


def design(recipe):
    builder = mesh.Builder(recipe["palette"])
    if recipe["shape"] == "organic":
        assert organic.build(builder, recipe)
    elif recipe["shape"] == "ring":
        import math

        # An open wheel with separate spokes and hub, never a filled saucer.
        n = 48
        for i in range(n):
            angles = [i * math.tau / n, (i + 1) * math.tau / n]
            points = [
                [r * math.cos(a), y, r * math.sin(a)]
                for y in [-6, 6]
                for r in [68, 88]
                for a in angles
            ]
            builder.component(
                points,
                [
                    [0, 1, 3, 2],
                    [4, 6, 7, 5],
                    [0, 4, 5, 1],
                    [2, 3, 7, 6],
                    [0, 2, 6, 4],
                    [1, 5, 7, 3],
                ],
                "hull",
                "habitation ring",
            )
        builder.loft([(-15, 12, 12), (15, 12, 12)], sections=12, name="hub")
        for a in [0, math.pi / 2, math.pi, math.pi * 1.5]:
            builder.box(
                (35 * math.cos(a), 0, 35 * math.sin(a)),
                (70, 5, 5),
                "secondary",
                "spoke",
                yaw=a,
            )
        surface.detail(builder, recipe)
    else:
        assert mechanical.build(builder, recipe), recipe["shape"]
        surface.detail(builder, recipe)
    return builder.result(recipe)
