"""Original family-aware mechanical hulls for the ship TOML authoring pipeline.

These silhouettes are project adaptations, not licensed manufacturer models or
claims of canon dimensions. Bow is -Z and dorsal is +Y. The mesh builder retains
semantic parts so the separate surface-detail pass can respect each assembly.
"""

import math


def cockpit(builder, x=0, y=15, z=-45, width=11, height=7, length=22):
    """A raised multi-plane canopy, embedded at its lower rim in the hull."""
    builder.loft(
        [
            (z - length / 2, width * 0.35, height * 0.45),
            (z - length * 0.2, width, height),
            (z + length / 2, width * 0.8, height * 0.75),
        ],
        (x, y),
        8,
        "cockpit",
        "cockpit canopy",
    )
    builder.box(
        (x, y - height * 0.6, z), (width * 2.1, 3, length), "trim", "canopy sill"
    )


def hardpoint(builder, x, y, z, size=1):
    builder.box(
        (x, y, z + 3 * size),
        (5 * size, 4 * size, 12 * size),
        "secondary",
        "hardpoint mount",
    )
    builder.loft(
        [(z - 9 * size, size, size), (z + 2 * size, size, size)],
        (x, y),
        6,
        "dark",
        "hardpoint barrel",
        0,
    )


def fin(builder, x, z, height=16, length=30, material="secondary", name="vertical fin"):
    """A closed swept vertical stabilizer, with a real thickness."""
    points = [
        [x + side, y, zz]
        for side in [-1.4, 1.4]
        for y, zz in [
            (0, z - length / 2),
            (height, z + 2),
            (height * 0.75, z + length / 2),
            (0, z + length / 2),
        ]
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


def pod(builder, x, y, front, rear, width, height, name="engine nacelle", sections=8):
    builder.loft(
        [
            (front, width * 0.45, height * 0.55),
            (front + 14, width, height),
            (rear - 13, width, height),
            (rear, width * 0.8, height * 0.8),
        ],
        (x, y),
        sections,
        "secondary",
        name,
    )
    builder.engine(x, y, rear, min(width, height) * 0.68, name)


def alliance(builder, variant):
    """Lakon central armoured cabin with physically separate engine arms."""
    builder.loft(
        [(-100, 12, 10), (-76, 28, 18), (-30, 34, 21), (38, 29, 19), (75, 20, 14)],
        sections=8,
        name="armoured command hull",
    )
    cockpit(builder, y=16, z=-75, width=16, length=28)
    # The Chieftain keeps four engines; Challenger substitutes a broad aft wing
    # and a central bank, while Crusader has a deep aft fighter-hangar section.
    for side in [-1, 1]:
        builder.wing(
            [(side * 23, -50), (side * 62, -37), (side * 70, -10), (side * 28, -7)],
            y=-1,
            thickness=10,
            name="forward engine arm",
        )
        pod(builder, side * 65, 0, -63, 3, 12, 11, "forward engine nacelle")
        if variant == 3:
            builder.wing(
                [(side * 25, 10), (side * 64, 22), (side * 73, 55), (side * 25, 50)],
                y=2,
                thickness=10,
                name="aft engine arm",
            )
            pod(builder, side * 68, 2, 4, 76, 16, 14, "aft engine nacelle")
        else:
            builder.wing(
                [(side * 24, 4), (side * 78, 31), (side * 73, 63), (side * 23, 52)],
                y=0,
                thickness=9,
                name="aft armour wing",
            )
            pod(builder, side * 53, -2, 28, 83, 16, 13, "aft engine nacelle")
        hardpoint(builder, side * 29, 16, -20, 1.2)
    builder.box((0, 23, 20), (25, 8, 37), "secondary", "dorsal equipment spine")
    if variant == 4:
        builder.loft(
            [(-10, 22, 10), (44, 24, 13), (75, 18, 10)],
            (0, -18),
            8,
            "secondary",
            "fighter hangar housing",
        )
        builder.box((0, -26, 56), (30, 2, 24), "dark", "fighter hangar door")
    if variant == 2:
        for x in [-10, 10]:
            builder.engine(x, 0, 78, 7, "central engine")


def krait(builder, variant):
    """Broad clipped triangular planform inherited from the original Krait."""
    phantom = variant == 73
    rear = 63 if phantom else 72
    builder.loft(
        [(-93, 9, 5), (-65, 35, 11), (-13, 69, 15), (37, 79, 14), (rear, 57, 10)],
        sections=8,
        name="triangular Krait hull",
        phase=math.pi / 8,
    )
    for side in [-1, 1]:
        builder.wing(
            [
                (side * 16, -74),
                (side * 52, -48),
                (side * 99, 48),
                (side * 78, rear + 2),
                (side * 48, 29),
            ],
            y=-3,
            thickness=7,
            name="integral delta wing",
        )
        builder.loft(
            [(-44, 6, 5), (12, 11, 8), (rear, 9, 7)],
            (side * 70, -1),
            6,
            "secondary",
            "wing structural spar",
        )
        builder.engine(side * 55, -1, rear + 1, 10, "outer drive")
        hardpoint(builder, side * 50, 7, -40, 1.3)
    cockpit(builder, y=8, z=-69, width=13, height=7, length=28)
    if not phantom:
        builder.engine(0, 0, rear + 2, 11, "centre drive")
        builder.box((0, -15, 23), (35, 5, 32), "dark", "fighter bay recess")
        builder.box((0, 16, 7), (24, 8, 33), "secondary", "dorsal machinery bay")
    else:
        builder.wing(
            [(-20, -22), (20, -22), (31, 45), (-31, 45)],
            y=15,
            thickness=3,
            material="secondary",
            name="Phantom heat deck",
        )


def mandalay(builder, variant):
    """Long explorer fuselage and swept gull wings, distinct from a delta hull."""
    builder.loft(
        [
            (-108, 5, 5),
            (-84, 17, 11),
            (-42, 23, 15),
            (19, 20, 16),
            (65, 13, 11),
            (88, 8, 7),
        ],
        sections=12,
        name="explorer fuselage",
        phase=0,
    )
    cockpit(builder, y=11, z=-69, width=12, height=8, length=31)
    for side in [-1, 1]:
        # Each convex wing segment rises away from the narrow central hull.
        builder.wing(
            [(side * 15, -36), (side * 48, -15), (side * 65, 46), (side * 20, 31)],
            y=5,
            thickness=6,
            name="gull wing root",
        )
        builder.wing(
            [(side * 46, -16), (side * 102, 33), (side * 97, 59), (side * 64, 47)],
            y=10,
            thickness=4,
            name="swept explorer wing",
        )
        pod(builder, side * 56, 6, 6, 83, 11, 9, "wing drive", 12)
        builder.wing(
            [(side * 90, 31), (side * 108, 48), (side * 103, 67), (side * 95, 57)],
            y=14,
            thickness=3,
            material="secondary",
            name="wingtip sensor fairing",
        )
    builder.engine(0, -2, 87, 7, "centre drive")
    fin(builder, 0, 66, 18, 32, name="explorer dorsal stabilizer")


def viper(builder, variant):
    """Slim pointed police wedge with swept shoulders, not an outrigger fighter."""
    heavy = variant == 139
    width = 38 if heavy else 32
    builder.loft(
        [
            (-105, 3, 3),
            (-70, 15, 8),
            (-22, width, 14),
            (35, width * 1.12, 17 if heavy else 13),
            (76, width * 0.77, 10),
        ],
        sections=8,
        name="Viper wedge hull",
    )
    cockpit(builder, y=11, z=-41, width=10, height=7, length=27)
    for side in [-1, 1]:
        builder.wing(
            [(side * 23, -28), (side * 47, 22), (side * 42, 60), (side * 25, 70)],
            y=-2,
            thickness=6 if heavy else 4,
            name="swept shoulder",
        )
        builder.engine(side * 19, -2, 77, 7.5 if heavy else 6.5, "main drive")
        hardpoint(builder, side * 16, -8, -52, 0.95)
    if variant == 137:
        fin(builder, 0, 48, 20, 35, name="Mk II dorsal fin")
    elif heavy:
        for side in [-1, 1]:
            builder.box(
                (side * 32, 7, 28), (11, 9, 38), "secondary", "Mk IV armour cheek"
            )
            hardpoint(builder, side * 34, 13, 12, 1.05)
    else:
        builder.box((0, 15, 28), (15, 5, 30), "secondary", "Mk III heat exchanger")


def type_freighter(builder, model):
    """Industrial family with distinct load bodies and exposed engine brackets."""
    if model == 6:
        builder.loft(
            [(-77, 22, 18), (-58, 34, 27), (40, 34, 27), (70, 27, 22)],
            sections=8,
            name="Type-6 cargo body",
        )
        cockpit(builder, y=8, z=-70, width=16, height=10, length=25)
        for side in [-1, 1]:
            builder.box(
                (side * 35, -4, 10), (8, 30, 88), "secondary", "cargo side rail"
            )
            pod(builder, side * 31, -22, 30, 80, 10, 10, "Type-6 drive")
    elif model == 7:
        builder.loft(
            [(-94, 24, 27), (-66, 38, 40), (50, 38, 40), (83, 27, 30)],
            sections=8,
            name="Type-7 tall cargo body",
        )
        cockpit(builder, y=10, z=-84, width=17, height=11, length=28)
        builder.box((0, 39, 14), (35, 7, 112), "secondary", "dorsal cargo trunk")
        for side in [-1, 1]:
            builder.box(
                (side * 39, 0, 20), (9, 48, 90), "secondary", "external cargo rail"
            )
            pod(builder, side * 34, -23, 42, 97, 13, 13, "Type-7 drive")
    elif model == 8:
        builder.loft(
            [(-100, 12, 11), (-65, 22, 17), (40, 22, 19), (78, 18, 15)],
            sections=8,
            name="Type-8 command spine",
        )
        cockpit(builder, y=13, z=-77, width=13, length=27)
        for side in [-1, 1]:
            builder.box(
                (side * 43, -3, 12), (31, 38, 115), "hull", "Type-8 cargo outrigger"
            )
            builder.box(
                (side * 26, 1, 20), (17, 14, 78), "secondary", "cargo attachment beam"
            )
            builder.wing(
                [(side * 53, -44), (side * 81, -20), (side * 82, 38), (side * 54, 65)],
                y=-2,
                thickness=11,
                name="Type-8 outer fairing",
            )
            pod(builder, side * 68, -2, 25, 83, 12, 12, "Type-8 drive")
    elif model in [9, 10]:
        builder.loft(
            [(-92, 24, 21), (-55, 53, 31), (51, 57, 34), (82, 43, 25)],
            sections=8,
            name="heavy cargo body",
        )
        cockpit(builder, y=13, z=-79, width=18, height=10, length=28)
        for side in [-1, 1]:
            builder.wing(
                [(side * 38, -53), (side * 86, -23), (side * 91, 56), (side * 51, 76)],
                y=0,
                thickness=25,
                name="heavy cargo shoulder",
            )
            builder.box(
                (side * 58, 21, 20), (29, 10, 78), "secondary", "cargo top trunk"
            )
            pod(builder, side * 67, -12, 34, 95, 17, 17, "heavy drive")
            builder.engine(side * 30, -15, 86, 10, "inner drive")
        if model == 10:
            # Distinctive Defender rear aerofoil and armoured dorsal housings.
            builder.wing(
                [(-75, 47), (75, 47), (82, 72), (-82, 72)],
                y=45,
                thickness=5,
                material="secondary",
                name="Defender aft aerofoil",
            )
            for x in [-49, 49]:
                builder.box((x, 33, 58), (8, 25, 14), "dark", "aerofoil support")
                hardpoint(builder, x, 31, -5, 1.8)
    else:
        builder.loft(
            [(-98, 11, 10), (-63, 27, 24), (40, 30, 26), (83, 22, 17)],
            sections=8,
            name="Type-11 mining spine",
        )
        cockpit(builder, y=14, z=-76, width=13, height=9, length=24)
        for side in [-1, 1]:
            builder.box((side * 40, -4, 15), (24, 37, 93), "hull", "mineral hopper")
            builder.box(
                (side * 52, -16, -55), (9, 12, 45), "secondary", "forward mining boom"
            )
            hardpoint(builder, side * 52, -18, -75, 1.6)
            pod(builder, side * 40, 17, 39, 89, 11, 11, "prospector drive")
        builder.box((0, -28, 19), (29, 6, 52), "dark", "mineral scoop aperture")


def federal(builder, variant):
    corvette = variant == 45
    builder.loft(
        [
            (-110 if corvette else -90, 9, 7),
            (-66, 27, 19),
            (-16, 42 if corvette else 35, 24),
            (51, 36, 24),
            (86, 25, 17),
        ],
        sections=8,
        name="Federal armoured keel",
    )
    cockpit(builder, y=21, z=-12 if corvette else -49, width=13, length=25)
    for side in [-1, 1]:
        builder.wing(
            [(side * 30, -39), (side * 65, 7), (side * 71, 59), (side * 30, 73)],
            y=-1,
            thickness=17,
            name="Federal armoured shoulder",
        )
        pod(builder, side * 46, -7, 36, 93, 13, 12, "Federal drive")
        hardpoint(builder, side * 29, 21, -28, 1.4)
    builder.box((0, 28, 41), (23, 9, 36), "secondary", "Federal dorsal machinery")
    if corvette:
        for side in [-1, 1]:
            hardpoint(builder, side * 19, 31, 33, 2.3)
        builder.loft(
            [(-30, 12, 7), (48, 17, 11), (82, 9, 8)],
            (0, -22),
            8,
            "secondary",
            "Corvette ventral keel",
        )
    elif variant == 46:
        builder.box((0, -24, 29), (35, 9, 55), "secondary", "dropship troop bay")
        builder.box((0, -29, 40), (25, 2, 32), "dark", "troop bay doors")
    elif variant == 47:
        for side in [-1, 1]:
            hardpoint(builder, side * 55, 14, 18, 1.5)
        fin(builder, 0, 48, 42, 38, name="gunship command tower")
    else:
        for side in [-1, 1]:
            fin(builder, side * 38, 48, 28, 31, name="assault stabilizer")


def imperial(builder, variant):
    if variant == 65:
        fighter(builder, variant)
        return
    cutter = variant == 64
    builder.loft(
        [
            (-110, 4, 4),
            (-79, 14, 9),
            (-30, 24, 16),
            (24, 25, 17),
            (65, 17, 12),
            (91, 8, 6),
        ],
        sections=16,
        name="Imperial streamlined fuselage",
        phase=0,
    )
    cockpit(builder, y=12, z=-58, width=12, height=7, length=29)
    for side in [-1, 1]:
        builder.wing(
            [
                (side * 17, -48),
                (side * 58, -28),
                (side * 93, 23),
                (side * 76, 49),
                (side * 24, 22),
            ],
            y=-1,
            thickness=6,
            name="Imperial swept wing",
        )
        pod(
            builder,
            side * 83,
            0,
            -30,
            83,
            13 if cutter else 11,
            10,
            "Imperial outrigger drive",
            16,
        )
        builder.wing(
            [(side * 76, -31), (side * 97, -2), (side * 98, 44), (side * 80, 76)],
            y=3,
            thickness=4,
            material="secondary",
            name="nacelle swept fairing",
        )
        if cutter:
            builder.wing(
                [
                    (side * 18, -73),
                    (side * 49, -57),
                    (side * 52, -36),
                    (side * 21, -44),
                ],
                y=0,
                thickness=3,
                name="Cutter forward canard",
            )
            builder.engine(side * 21, -2, 87, 8, "Cutter inboard drive")
    builder.engine(0, -2, 94, 7, "Imperial centre drive")


def liner(builder, variant):
    beluga, dolphin = variant == 12, variant == 35
    body_width = 26 if beluga else 17 if dolphin else 20
    body_height = 21 if beluga else 14
    builder.loft(
        [
            (-115, 3, 4),
            (-98, body_width * 0.65, body_height * 0.8),
            (-62, body_width, body_height),
            (39, body_width, body_height),
            (82, body_width * 0.75, body_height * 0.8),
            (101, 6, 7),
        ],
        sections=16,
        name="passenger liner hull",
        phase=0,
    )
    cockpit(
        builder,
        y=body_height * 0.6,
        z=-92,
        width=body_width * 0.65,
        height=5,
        length=23,
    )
    for side in [-1, 1]:
        # Flush window galleries follow the long cabin body; broad smooth hull
        # panels are intentional on the liners, unlike exposed industrial gear.
        builder.box(
            (side * body_width * 0.94, 3, -9),
            (2, 5, 102),
            "cockpit",
            "passenger window gallery",
        )
        builder.wing(
            [
                (side * body_width * 0.7, 18),
                (side * (74 if beluga else 48), 48),
                (side * (67 if beluga else 43), 70),
                (side * body_width * 0.6, 62),
            ],
            y=-4,
            thickness=4,
            name="liner aft wing",
        )
        pod(
            builder,
            side * (58 if beluga else 36),
            -3,
            32,
            103,
            9 if beluga else 7,
            8,
            "liner nacelle",
            16,
        )
    if beluga:
        fin(builder, 0, 68, 42, 40, name="Beluga dorsal tail")
    elif not dolphin:
        fin(builder, 0, 69, 26, 36, name="Orca dorsal tail")
    builder.engine(0, -2, 104, 6, "liner centre drive")


def anaconda(builder, variant):
    builder.loft(
        [
            (-128, 3, 4),
            (-93, 14, 11),
            (-37, 28, 20),
            (33, 37, 27),
            (80, 29, 23),
            (107, 22, 16),
        ],
        sections=8,
        name="Anaconda long tapered hull",
    )
    cockpit(builder, y=26, z=31, width=16, height=8, length=31)
    for side in [-1, 1]:
        builder.loft(
            [(-45, 6, 5), (23, 10, 9), (79, 8, 8)],
            (side * 29, -1),
            6,
            "secondary",
            "Anaconda side armour rail",
        )
        builder.engine(side * 17, 2, 109, 10, "Anaconda drive")
        hardpoint(builder, side * 23, 14, -36, 1.3)
    builder.box((0, 29, 69), (21, 9, 27), "secondary", "Anaconda bridge machinery")
    builder.box((0, -24, 29), (28, 7, 57), "secondary", "Anaconda ventral keel")


def cobra(builder, variant):
    mk5 = variant == 25
    builder.loft(
        [(-82, 13, 4), (-44, 41, 14), (18, 62, 19), (65, 49, 12)],
        sections=8,
        name="Cobra broad wedge hull",
    )
    for side in [-1, 1]:
        builder.wing(
            [(side * 20, -64), (side * 78, 18), (side * 68, 54), (side * 38, 64)],
            y=-1,
            thickness=6,
            name="Cobra swept shoulder",
        )
        pod(builder, side * 33, -3, 37, 73, 11, 9, "Cobra drive")
        hardpoint(builder, side * 25, 12, -35, 1.05)
        if mk5:
            builder.wing(
                [(side * 55, -14), (side * 84, 13), (side * 78, 35), (side * 56, 24)],
                y=5,
                thickness=4,
                material="secondary",
                name="Mk V wing armour",
            )
    cockpit(builder, y=12, z=-39, width=15, height=6, length=23)
    builder.box(
        (0, 20, 28), (22 if mk5 else 31, 6, 29), "secondary", "Cobra dorsal heat deck"
    )


def python(builder, variant):
    builder.loft(
        [(-111, 4, 4), (-75, 16, 8), (-16, 43, 18), (42, 48, 20), (80, 33, 13)],
        sections=8,
        name="Python tapered hull",
    )
    cockpit(builder, y=16, z=-17, width=12, height=8, length=29)
    for side in [-1, 1]:
        builder.wing(
            [(side * 28, -39), (side * 59, 22), (side * 56, 63), (side * 29, 78)],
            y=-4,
            thickness=8,
            name="Python shoulder hull",
        )
        pod(builder, side * 27, -3, 48, 88, 11, 10, "Python main drive")
        hardpoint(builder, side * 26, 16, -6, 1.35)
    builder.engine(0, -6, 85, 7, "Python centre drive")
    builder.box((0, 22, 35), (19, 7, 36), "secondary", "Python dorsal spine")


def asp(builder, variant):
    scout = variant == 11
    builder.loft(
        [(-89, 12, 7), (-49, 40, 20), (7, 63, 24), (62, 43, 17)],
        sections=8,
        name="Asp hexagonal hull",
    )
    cockpit(builder, y=8, z=-73, width=18, height=9, length=25)
    for side in [-1, 1]:
        builder.wing(
            [(side * 28, -57), (side * 78, 2), (side * 57, 53), (side * 30, 60)],
            y=-2,
            thickness=8,
            name="Asp angular shoulder",
        )
        builder.engine(
            side * (31 if scout else 37), -4, 65, 10 if scout else 13, "Asp drive"
        )
        hardpoint(builder, side * 37, -13, -33, 1.1)
    if not scout:
        builder.box((0, 24, 19), (25, 7, 31), "secondary", "Asp survey equipment")


def diamondback(builder, variant):
    explorer = variant == 32
    builder.loft(
        [(-97, 9, 8), (-63, 24, 18), (-9, 29, 25), (44, 24, 21), (72, 17, 12)],
        sections=8,
        name="Diamondback command hull",
    )
    cockpit(builder, y=16, z=-65, width=15, height=10, length=27)
    for side in [-1, 1]:
        builder.wing(
            [(side * 18, -39), (side * 47, -9), (side * 52, 40), (side * 21, 53)],
            y=-3,
            thickness=10,
            name="Diamondback side arm",
        )
        pod(builder, side * 44, -4, -10, 80, 12, 14, "Diamondback external drive")
        hardpoint(builder, side * 24, -15, -48, 1)
    if explorer:
        builder.box((0, 27, 22), (22, 12, 39), "secondary", "explorer sensor rack")
        builder.box((0, -27, 17), (27, 6, 45), "dark", "explorer scoop")
    else:
        fin(builder, 0, 42, 34, 31, name="scout dorsal fin")


def carrier(builder, variant):
    """Capital/transport silhouettes, with bays rather than fighter-size wings."""
    imperial_capital = variant == 81
    bulk = variant in [79, 80]
    builder.loft(
        [(-145, 13, 10), (-108, 27, 21), (42, 30, 23), (119, 23, 19)],
        sections=12 if imperial_capital else 8,
        name="capital command spine",
    )
    for side in [-1, 1]:
        if bulk:
            for z in [-75, -25, 25, 75]:
                builder.box(
                    (side * 44, -3, z), (34, 37, 43), "hull", "bulk cargo module"
                )
                builder.box((side * 26, 0, z), (14, 14, 26), "dark", "cargo truss")
        else:
            builder.loft(
                [(-76, 15, 11), (-42, 24, 16), (87, 24, 16), (118, 16, 12)],
                (side * 54, -4),
                12 if imperial_capital else 8,
                "hull",
                "capital side hull",
            )
            for z in [-38, 35, 89]:
                builder.box(
                    (side * 31, -4, z),
                    (34, 12, 18),
                    "secondary",
                    "capital transverse beam",
                )
            builder.box((side * 77, -2, 26), (2, 16, 57), "dark", "hangar mouth")
            for z in [-26, 40, 91]:
                hardpoint(builder, side * 48, 14, z, 1.8)
        builder.engine(side * 45, -6, 124, 13, "capital drive")
    builder.loft(
        [(-6, 11, 6), (29, 17, 12), (69, 12, 9)],
        (0, 31),
        8,
        "secondary",
        "raised command bridge",
    )
    cockpit(builder, y=41, z=21, width=13, height=4, length=32)
    builder.engine(0, 0, 125, 14, "capital centre drive")
    if variant == 78:
        builder.box(
            (0, 28, -55), (29, 12, 65), "secondary", "cruiser accommodation deck"
        )
        for side in [-1, 1]:
            builder.box(
                (side * 16, 29, -55), (2, 4, 57), "cockpit", "cruiser window gallery"
            )
    elif variant == 80:
        builder.loft(
            [(-110, 11, 8), (-66, 21, 14), (70, 21, 14), (100, 12, 9)],
            (0, 31),
            12,
            "secondary",
            "Highliner passenger gallery",
        )
        for side in [-1, 1]:
            builder.box(
                (side * 20, 34, -8), (2, 5, 121), "cockpit", "Highliner windows"
            )
    if imperial_capital:
        for side in [-1, 1]:
            builder.wing(
                [
                    (side * 20, -102),
                    (side * 80, -54),
                    (side * 93, -8),
                    (side * 31, -39),
                ],
                y=2,
                thickness=6,
                name="Interdictor forward sweep",
            )


def fighter(builder, variant):
    """Compact fighting hulls; classes get distinct functional assemblies."""
    imperial = variant in [54, 65]
    guardian = variant in [145, 146, 147]
    condor = variant == 41
    vulture = variant == 140
    if guardian:
        builder.loft(
            [(-89, 3, 3), (-43, 13, 7), (34, 16, 8), (68, 7, 5)],
            sections=6,
            name="Guardian-derived central spear",
        )
        for side in [-1, 1]:
            builder.wing(
                [(side * 7, -46), (side * 76, -16), (side * 66, 4), (side * 16, 42)],
                y=0,
                thickness=4,
                name="swept crystalline wing",
            )
            pod(builder, side * 23, -3, 19, 69, 6, 6, "spear drive", 6)
        cockpit(builder, y=7, z=-30, width=6, height=4, length=19)
        if variant == 146:
            hardpoint(builder, 0, -7, -57, 1.6)
        elif variant == 147:
            fin(builder, 0, 23, 29, 40, name="Lance dorsal blade")
    elif imperial:
        gu97 = variant == 54
        builder.loft(
            [
                (-66 if gu97 else -96, 3, 3),
                (-31 if gu97 else -47, 20 if gu97 else 16, 14 if gu97 else 10),
                (32, 18 if gu97 else 17, 13 if gu97 else 11),
                (66, 7, 5),
            ],
            sections=12,
            name="Imperial fighter fuselage",
            phase=0,
        )
        for side in [-1, 1]:
            builder.wing(
                [
                    (side * 12, -36 if gu97 else -46),
                    (side * 81, 11 if gu97 else 37),
                    (side * 66, 58),
                    (side * 20, 23),
                ],
                y=0,
                thickness=4,
                name="Imperial swept fighter wing",
            )
            pod(
                builder,
                side * (59 if gu97 else 52),
                -1,
                -9 if gu97 else 6,
                70,
                7,
                7,
                "Imperial fighter drive",
                12,
            )
        cockpit(
            builder,
            y=12 if gu97 else 10,
            z=-25 if gu97 else -40,
            width=10 if gu97 else 8,
            height=5,
            length=21,
        )
    elif condor:
        builder.loft(
            [(-76, 5, 4), (-29, 24, 9), (31, 26, 9), (60, 14, 6)],
            sections=8,
            name="Condor command wedge",
        )
        for side in [-1, 1]:
            builder.wing(
                [(side * 13, -55), (side * 72, 19), (side * 49, 45), (side * 20, 17)],
                y=0,
                thickness=4,
                name="Condor delta wing",
            )
            builder.engine(side * 17, -1, 63, 7, "Condor drive")
            hardpoint(builder, side * 31, 3, -10, 1)
        cockpit(builder, y=7, z=-27, width=9, height=5, length=23)
    else:
        # Named variants differ in body proportions, wing sweep and drive
        # placement before the surface-detail pass. These are authored choices.
        body, width, sweep, drive = {
            42: (26, 68, 12, 27),
            56: (22, 58, -4, 32),
            59: (19, 77, 23, 20),
            69: (20, 77, -33, 28),
            70: (23, 83, -19, 21),
            85: (20, 53, 4, 20),
            94: (27, 73, -10, 23),
            103: (18, 60, 28, 30),
            110: (28, 48, 2, 18),
            111: (23, 65, 18, 23),
            140: (29, 60, 7, 35),
        }.get(variant, (23, 65, 18, 24))
        builder.loft(
            [
                (-100, 3, 3),
                (-58, body * 0.6, 9),
                (-5, body, 17 if vulture else 13),
                (58, body * 0.8, 10),
            ],
            sections=8,
            name="fighter central hull",
        )
        for side in [-1, 1]:
            builder.wing(
                [
                    (side * 13, -31),
                    (side * width, sweep),
                    (side * (width - 8), 49),
                    (side * 18, 36),
                ],
                y=0,
                thickness=9 if vulture else 5,
                name="fighter wing",
            )
            pod(
                builder,
                side * drive,
                -3,
                21,
                76,
                12 if vulture else 8,
                11 if vulture else 7,
                "fighter drive",
            )
            hardpoint(
                builder, side * (30 if vulture else 18), 11, -20, 1.65 if vulture else 1
            )
        cockpit(builder, y=11, z=-42, width=10, height=6, length=25)
        if variant in [42, 56, 59, 85, 94, 103, 110]:
            fin(builder, 0, 39, 31, 36, name="fighter dorsal stabilizer")
        elif variant == 111:
            for side in [-1, 1]:
                fin(builder, side * 35, 40, 23, 27, name="Taipan twin stabilizer")


def utility(builder, variant):
    builder.loft(
        [(-88, 12, 13), (-54, 28, 23), (41, 29, 24), (71, 20, 17)],
        sections=8,
        name="utility cabin hull",
    )
    cockpit(builder, y=14, z=-66, width=15, height=9, length=26)
    for side in [-1, 1]:
        builder.box(
            (side * 29, -2, 16), (10, 24, 67), "secondary", "utility mounting rail"
        )
        pod(builder, side * 27, -19, 30, 81, 10, 10, "utility drive")
    builder.box((0, -25, 24), (32, 5, 47), "dark", "utility cargo hatch")
    if variant == 91:
        builder.box((0, 28, 20), (22, 11, 32), "secondary", "Nomad survey rack")
    elif variant == 68:
        for side in [-1, 1]:
            builder.box(
                (side * 39, 5, 38), (16, 18, 34), "secondary", "Keelback thrust housing"
            )
            builder.engine(side * 39, 5, 57, 6, "Keelback manoeuvre drive")


def freighter(builder, variant):
    heavy = variant in [19, 97]
    width = 43 if heavy else 30
    builder.loft(
        [(-99, 13, 14), (-58, width, 27), (53, width, 28), (87, width * 0.7, 21)],
        sections=8,
        name="freighter cargo hull",
    )
    cockpit(builder, y=16, z=-75, width=16, height=9, length=29)
    for side in [-1, 1]:
        builder.box(
            (side * width, -3, 8), (15, 35, 106), "secondary", "freighter load rail"
        )
        pod(builder, side * width * 0.8, -14, 45, 97, 13, 12, "freighter drive")
        if heavy:
            for z in [-28, 27]:
                builder.box(
                    (side * (width + 20), -7, z),
                    (25, 38, 45),
                    "hull",
                    "auxiliary cargo pod",
                )
    if variant in [74, 75]:
        builder.loft(
            [(-40, 13, 7), (29, 16, 10), (64, 11, 7)],
            (0, 32),
            8,
            "secondary",
            "Lanner raised service deck",
        )
    if variant == 97:
        builder.box(
            (0, -30, 21), (48, 16, 94), "secondary", "Panther ventral cargo keel"
        )
        for side in [-1, 1]:
            builder.box(
                (side * 37, 31, 26),
                (17, 12, 71),
                "secondary",
                "Panther dorsal load trunk",
            )
    if variant == 75:
        builder.box(
            (0, -28, 24), (32, 10, 67), "secondary", "Lanner II expanded cargo keel"
        )
        builder.engine(0, -22, 93, 7, "Lanner II auxiliary drive")
    if variant == 106:
        builder.box((0, -28, 41), (39, 8, 53), "secondary", "shuttle passenger bay")


LEGACY_WINGS = {
    18: ([(24, -24), (72, 4), (64, 32), (34, 34)], -8, 8, "Caiman shoulder wing"),
    29: ([(14, -65), (42, -48), (46, -25), (19, -32)], 1, 4, "Corsair forward canard"),
    31: ([(7, -86), (84, 45), (39, 62), (18, -17)], 0, 5, "Delta integral wing"),
    57: ([(18, -17), (74, 18), (67, 55), (22, 39)], 6, 7, "Harris attack wing"),
    84: ([(15, 8), (47, -61), (59, -42), (34, 44)], -6, 6, "Mantis forward claw"),
    108: ([(14, -42), (76, -1), (74, 36), (27, 56)], 0, 3, "Skeet shallow wing"),
    109: ([(13, 37), (42, -73), (52, -63), (29, 62)], -5, 6, "Spar forward outrigger"),
    126: ([(16, -30), (81, 9), (71, 36), (22, 22)], 5, 4, "Tiercel swept blade"),
    144: ([(18, -16), (76, 33), (66, 60), (23, 28)], 8, 5, "Wyvern upper wing"),
}
LEGACY_PODS = {
    18: (49, -8, 13, 85, 10, 10, "Caiman shoulder drive"),
    77: (38, 0, -21, 80, 13, 16, "Lion armoured drive"),
    126: (57, 4, -2, 83, 8, 9, "Tiercel wing drive"),
}


def legacy_appendages(builder, variant):
    """Explicit authored role assemblies for the otherwise unrelated old names."""
    wing = LEGACY_WINGS.get(variant)
    if wing:
        outline, y, thickness, name = wing
        for side in [-1, 1]:
            builder.wing(
                [(side * x, z) for x, z in outline], y, thickness, "hull", name
            )
    nacelle = LEGACY_PODS.get(variant)
    if nacelle:
        x, y, front, rear, width, height, name = nacelle
        for side in [-1, 1]:
            pod(builder, side * x, y, front, rear, width, height, name)
    if variant == 7:
        builder.loft(
            [(-22, 11, 8), (28, 15, 11), (60, 8, 7)],
            (0, 24),
            8,
            "secondary",
            "Quest survey bridge",
        )
    elif variant == 17:
        builder.box((0, -17, 26), (38, 18, 63), "secondary", "Bushmaster cargo keel")
        builder.box((0, -27, 29), (27, 2, 39), "dark", "Bushmaster load hatch")
    elif variant == 27:
        for side in [-1, 1]:
            builder.loft(
                [(-61, 4, 5), (-24, 9, 10), (37, 7, 9)],
                (side * 24, 4),
                6,
                "secondary",
                "Copperhead armour cheek",
            )
    elif variant == 30:
        for side in [-1, 1]:
            fin(builder, side * 19, 40, 25, 33, name="Cougar twin fin")
    elif variant == 36:
        builder.loft(
            [(-33, 9, 5), (26, 15, 11), (62, 10, 7)],
            (0, 24),
            8,
            "secondary",
            "Drake raised command spine",
        )
        fin(builder, 0, 43, 43, 39, name="Drake dorsal tail")
    elif variant == 55:
        for side in [-1, 1]:
            builder.box(
                (side * 31, -3, -44), (8, 9, 65), "secondary", "Gyr forward spar"
            )
            hardpoint(builder, side * 31, -3, -80, 1.2)
    elif variant == 101:
        builder.box((0, -10, 5), (16, 5, 85), "secondary", "Racer ventral heat channel")
        fin(builder, 0, 62, 35, 30, name="Racer tail blade")
    elif variant == 135:
        for side in [-1, 1]:
            fin(builder, side * 25, 42, 33, 35, name="Urutu twin stabilizer")
    elif variant == 144:
        for side in [-1, 1]:
            builder.wing(
                [(side * 20, -21), (side * 63, 16), (side * 58, 42), (side * 24, 29)],
                -10,
                4,
                "secondary",
                "Wyvern lower wing",
            )


def wedge(builder, variant):
    """Unrelated legacy concepts get distinct role assemblies and hull form."""
    if variant == 19:
        freighter(builder, variant)
        return
    form = 4 if variant == 101 else variant % 6
    if form == 0:
        builder.loft(
            [(-98, 4, 4), (-45, 29, 14), (25, 47, 19), (75, 31, 11)],
            sections=8,
            name="angular multirole hull",
        )
    elif form == 1:
        builder.loft(
            [(-103, 3, 3), (-48, 21, 13), (20, 33, 20), (77, 24, 14)],
            sections=8,
            name="long patrol hull",
        )
    elif form == 2:
        builder.loft(
            [(-90, 8, 5), (-32, 40, 19), (24, 49, 22), (68, 25, 13)],
            sections=8,
            name="broad survey hull",
        )
    elif form == 3:
        builder.loft(
            [(-95, 10, 10), (-58, 23, 20), (31, 30, 24), (74, 20, 15)],
            sections=8,
            name="armoured utility hull",
        )
    elif form == 4:
        builder.loft(
            [(-117, 3, 3), (-55, 13, 8), (24, 20, 14), (88, 13, 9)],
            sections=8,
            name="needle interceptor hull",
        )
    else:
        builder.loft(
            [(-97, 5, 5), (-44, 20, 15), (21, 35, 20), (70, 22, 12)],
            sections=8,
            name="gull patrol hull",
        )
    cockpit(builder, y=13, z=-48, width=10, height=7, length=25)
    for side in [-1, 1]:
        if form in [1, 4, 5]:
            builder.wing(
                [
                    (side * 14, -39),
                    (side * (67 if form == 5 else 53), 7),
                    (side * 46, 45),
                    (side * 18, 34),
                ],
                y=-2,
                thickness=5,
                name="swept utility wing",
            )
        builder.engine(side * 17, -2, 80 if form != 4 else 91, 7, "patrol drive")
        hardpoint(builder, side * 20, 9, -26, 1.15)
    if form in [0, 2, 3]:
        builder.box((0, 23, 27), (20, 7, 34), "secondary", "dorsal service deck")
    if form == 4:
        fin(builder, 0, 43, 27, 31, name="interceptor stabilizer")
    legacy_appendages(builder, variant)


BUILDERS = {
    "alliance": alliance,
    "krait": krait,
    "mandalay": mandalay,
    "viper": viper,
    "federal": federal,
    "imperial": imperial,
    "liner": liner,
    "anaconda": anaconda,
    "cobra": cobra,
    "python": python,
    "asp": asp,
    "diamondback": diamondback,
    "carrier": carrier,
    "fighter": fighter,
    "utility": utility,
    "freighter": freighter,
    "wedge": wedge,
}


def build(builder, recipe):
    """Build a supported mechanical shape, otherwise leave the builder untouched."""
    shape = recipe.get("shape", "")
    if shape in {f"type{i}" for i in range(6, 12)}:
        type_freighter(builder, int(shape[4:]))
        return True
    author = BUILDERS.get(shape)
    if author is None:
        return False
    author(builder, int(recipe["variant"]))
    return True
