"""Author the 30 October design proposal. This does not edit runtime resources.

Run with Python 3.11+ and --source-workspace pointing to the frozen proposal.
Numeric rows are authored design decisions, not measurements or test results.
"""

from __future__ import annotations

import argparse
import collections
import hashlib
import json
import math
from pathlib import Path
import tomllib


# ID cargo speed energy recharge jump missiles facing crew equipment utility niche.
# Each line is an explicit hull decision. No ID-based jitter or inherited-game table.
ROWS = """
001 76 33.2 290 4.0 9 5 3 2 20 3 modular-courier
018 58 39.0 220 3.1 10 4 3 1 16 2 frontier-trader
021 66 34.0 330 3.4 9 6 15 2 20 2 escorted-merchant
022 64 37.0 260 3.2 9 5 3 1 18 2 light-multirole
023 78 35.7 320 3.7 9 7 7 1 20 2 armed-multirole
024 86 34.6 360 4.0 10 6 15 2 24 3 expedition-multirole
025 92 34.3 380 4.2 9 9 15 1 24 3 starter-multirole
027 54 36.2 270 3.8 11 4 3 1 18 3 remote-outpost-trader
029 60 37.8 280 3.5 10 5 3 1 20 3 mixed-contract-courier
036 72 33.0 300 3.9 11 4 3 2 22 3 long-haul-merchant
050 80 31.5 340 4.3 10 5 3 2 24 3 cold-route-trader
052 68 37.4 250 3.3 9 4 3 1 18 2 express-merchant
061 84 32.7 310 3.6 9 5 7 2 22 3 regional-trader
067 74 31.0 420 4.1 9 6 15 3 24 2 armoured-trader
084 62 36.5 240 3.7 11 4 3 1 20 3 expedition-supply
086 60 35.8 290 4.0 10 4 3 2 22 3 precision-freight
087 70 34.8 320 3.8 10 5 7 2 22 2 independent-merchant
089 52 41.0 220 3.0 10 4 1 1 16 2 blockade-courier
090 96 29.5 440 4.2 9 6 15 3 26 3 heavy-local-trader
092 64 35.2 300 4.1 9 5 7 2 20 3 station-supply
104 78 30.8 370 4.6 9 4 3 3 26 4 utility-service
109 82 30.0 410 4.0 8 6 15 3 24 2 defended-short-haul
126 56 37.2 260 3.6 10 5 3 1 18 2 small-lot-trader
127 88 32.0 350 4.4 10 5 7 3 26 3 modular-supply
135 54 39.2 270 3.5 9 5 3 1 18 2 opportunist-trader
144 66 38.4 250 3.2 9 6 3 1 18 2 armed-express
005 1108 17.7 1120 6.4 7 7 15 12 48 4 container-hauler
006 1220 16.8 1300 7.1 7 8 15 14 54 4 heavy-container-hauler
013 396 21.9 710 5.2 10 6 7 6 34 3 drum-freighter
014 460 20.5 850 5.9 10 7 15 7 38 3 defended-drum-freighter
058 430 20.2 860 5.6 8 6 15 7 38 4 industrial-lift
062 360 27.0 600 5.1 9 5 3 4 30 3 fast-freighter
064 340 25.6 670 5.5 10 5 3 5 32 4 service-freighter
074 420 20.8 740 5.3 11 5 3 6 36 3 frontier-hauler
075 480 19.8 880 6.0 10 6 7 8 40 4 long-endurance-hauler
076 450 19.0 900 5.8 8 6 15 7 38 3 compact-bulk-hauler
077 380 23.2 690 5.0 10 5 3 5 32 3 regional-bulk-hauler
079 786 19.6 970 6.4 7 7 7 9 44 4 modular-freighter
080 680 21.0 1020 6.8 10 6 7 10 48 4 long-range-highliner
096 188 27.2 420 4.4 9 5 3 3 26 3 entry-freighter
097 224 25.6 490 4.9 9 6 7 4 30 3 expanded-entry-freighter
098 330 25.1 620 5.0 10 5 3 4 30 3 compact-logistics
099 440 22.6 710 5.2 8 6 7 6 34 3 low-cost-bulk
100 510 20.8 840 5.9 8 7 15 8 38 3 armoured-bulk
105 300 23.0 680 5.6 9 4 3 5 38 4 passenger-shuttle
106 360 21.5 800 6.2 10 5 7 7 44 4 passenger-transport
128 374 23.1 640 5.2 8 6 7 5 32 3 medium-freighter
131 220 27.0 510 4.7 9 4 3 3 28 3 light-freighter
132 440 21.3 730 6.2 8 6 7 6 36 3 standard-freighter
133 350 20.0 790 6.5 12 5 3 6 40 4 tanker-support
134 620 18.0 980 6.0 8 8 15 9 44 3 heavy-industrial-freighter
150 528 20.8 740 5.2 8 6 7 8 40 4 winter-convoy-freighter
166 280 25.0 820 6.7 10 4 3 8 46 4 rescue-transport
002 14 44.8 420 5.4 8 8 7 1 16 1 assault-fighter
003 28 39.0 460 6.8 10 5 15 3 24 3 command-support
004 20 44.0 340 5.0 10 6 3 2 18 2 long-patrol
009 20 42.0 420 6.2 8 8 7 1 18 2 heavy-fighter
010 16 40.0 470 7.4 9 5 3 2 22 3 electronic-support
011 12 48.0 280 4.5 12 4 1 1 16 3 military-recon
026 18 44.5 390 5.8 8 7 7 1 18 2 hammerhead-strike
031 10 55.0 270 4.6 9 6 1 1 14 1 point-interceptor
033 14 50.2 300 4.9 11 5 3 1 16 2 fast-recon
041 20 43.6 390 6.1 9 6 7 1 18 2 close-escort
042 12 51.0 330 5.2 10 5 3 1 16 2 border-interceptor
044 18 42.4 480 6.0 8 8 7 2 20 2 armoured-assault
045 32 36.0 610 7.0 9 9 15 5 28 3 corvette-escort
046 48 36.8 450 5.8 9 4 3 5 30 4 orbital-dropship
047 14 38.0 560 8.2 8 9 15 3 24 2 sustained-gunship
053 10 52.0 300 5.0 10 5 1 1 16 2 prototype-recon
054 12 49.0 280 4.8 9 6 3 1 14 1 light-dogfighter
056 10 56.0 260 4.4 9 5 1 1 14 1 sprint-interceptor
057 10 51.8 310 5.4 8 6 3 1 16 1 agile-dogfighter
059 24 41.0 440 6.0 10 6 7 2 20 2 expedition-escort
063 26 48.0 300 4.6 12 4 3 1 20 3 military-courier
069 16 46.3 350 5.2 9 7 7 1 18 2 medium-fighter
094 16 46.0 370 5.8 10 6 3 1 18 2 border-fighter
095 12 43.0 520 7.5 9 5 3 2 22 3 emp-interdictor
110 18 43.0 450 5.7 8 8 7 2 20 2 strike-fighter
111 12 53.0 300 4.8 9 6 1 1 16 1 fast-strike
129 36 35.5 650 7.2 8 9 15 4 26 3 convoy-guard
136 10 55.0 270 4.2 8 6 1 1 14 1 light-interceptor
137 12 53.0 320 4.8 9 7 3 1 16 1 interceptor-patrol
138 14 50.5 390 5.8 9 8 7 2 18 2 interceptor-escort
139 16 47.0 470 6.8 10 9 15 2 22 2 heavy-interceptor
145 14 48.0 320 5.0 9 4 3 1 16 2 internal-ordnance-fighter
146 12 50.0 290 5.6 10 5 1 1 16 2 precision-interceptor
147 18 43.2 410 6.4 10 6 7 2 20 2 endurance-escort
148 16 45.0 380 6.5 11 5 3 2 20 3 night-patrol
151 24 43.0 400 6.0 10 6 7 2 22 3 winter-convoy-escort
152 12 49.0 300 4.8 12 4 1 1 18 3 deep-recon
153 14 46.0 440 6.2 8 9 7 1 18 1 missile-strike
154 24 42.0 410 6.4 11 6 3 2 22 3 endurance-patrol
155 64 35.0 500 7.4 10 5 15 6 34 4 fleet-support
157 16 46.2 350 5.1 12 4 3 1 18 3 frontier-recon
158 18 48.2 360 4.8 8 7 7 1 18 2 pack-fighter
159 22 45.7 440 5.9 9 8 15 2 22 2 heavy-pack-fighter
160 30 40.0 460 6.8 10 5 3 3 26 4 boarding-support
165 18 45.5 360 5.6 10 6 7 2 20 2 multi-role-patrol
167 28 42.0 350 6.1 12 4 3 3 26 4 military-survey
169 16 46.4 340 5.0 9 7 7 1 18 2 light-strike
170 22 43.8 420 6.2 10 8 15 2 22 2 defended-strike
030 22 51.0 330 5.0 10 5 3 1 18 2 pursuit-patrol
048 10 65.3 190 3.6 9 4 1 1 14 1 sprint-pursuit
070 20 53.1 310 4.8 10 6 3 1 18 2 missile-pursuit
082 14 57.0 250 3.8 9 4 1 1 16 1 close-pursuit
085 18 54.1 280 4.4 10 5 3 1 18 2 independent-hunter
103 26 51.4 430 6.2 9 8 15 2 24 3 heavy-bounty-hunter
108 24 47.8 390 5.4 11 5 7 2 22 3 evidence-recovery
140 20 55.0 280 4.2 10 5 3 1 18 2 long-pursuit
142 30 46.5 460 6.5 9 6 15 3 26 4 salvage-hunter
149 22 50.5 340 5.0 12 6 3 2 22 3 distant-warrant-hunter
015 30 46.0 250 3.3 9 5 3 2 20 3 cargo-raider
020 18 54.0 210 3.5 11 4 1 1 18 2 raider-scout
037 14 58.3 140 2.7 8 4 1 1 14 1 hit-and-run
038 18 55.8 210 3.6 9 5 3 1 18 2 armed-raider
039 24 52.5 300 4.8 9 7 7 2 22 3 heavy-raider
049 32 49.5 280 3.8 8 6 7 2 22 3 pack-raider
051 28 48.0 250 4.3 10 5 3 2 22 3 opportunist-salvager
055 38 43.0 320 4.1 9 5 15 3 26 4 wreck-scavenger
065 20 56.0 180 3.2 8 5 3 1 18 2 cockpit-ring-raider
071 26 48.0 270 3.6 9 5 3 2 22 3 armed-scavenger
072 34 45.0 350 4.5 10 7 15 3 26 3 defended-raider
073 20 53.0 220 3.9 11 4 1 1 20 3 reconnaissance-raider
107 26 50.0 240 3.8 12 4 3 2 22 3 long-range-scavenger
163 36 44.0 410 5.4 10 6 7 3 28 4 salvage-raider
016 128 25.0 400 5.2 8 4 3 3 28 3 extraction-miner
017 96 29.0 350 4.8 11 4 1 2 26 4 prospecting-miner
060 88 28.5 430 5.8 8 5 3 3 28 3 deep-work-miner
068 116 25.5 470 6.4 9 5 7 4 32 4 salvage-miner
091 100 29.5 360 5.0 10 4 3 2 26 3 scout-miner
130 200 22.0 620 7.2 9 6 7 6 38 4 industrial-miner
143 104 26.0 500 6.8 10 4 3 4 34 4 sustained-extraction
168 82 32.0 330 4.6 10 4 3 2 24 3 mobile-prospector
007 60 38.0 260 3.8 12 4 3 2 26 3 expedition-voyager
008 40 41.0 250 4.6 13 4 1 2 26 4 survey-explorer
012 160 31.0 400 5.3 12 4 3 6 40 3 long-distance-liner
019 34 43.0 230 3.8 14 4 1 1 24 3 range-explorer
032 32 47.0 220 3.6 12 4 3 1 22 3 fast-explorer
035 100 35.0 330 4.8 11 4 3 4 34 3 regional-liner
066 28 49.0 200 3.5 11 4 1 1 20 2 light-explorer
078 80 36.5 320 5.2 13 4 3 3 32 4 expedition-support
083 36 45.0 240 4.4 12 4 1 1 24 3 reconnaissance-explorer
088 200 29.0 470 5.8 12 4 3 8 46 4 starliner
093 120 33.0 380 5.0 12 4 3 5 38 3 comfort-liner
101 10 61.0 170 3.0 10 4 1 1 14 1 racer
112 28 45.0 470 6.4 10 5 7 2 26 3 alien-defender
113 22 49.0 420 5.8 9 7 3 1 22 2 alien-striker
114 24 43.0 520 7.0 10 4 15 3 28 3 alien-sentinel
115 18 55.0 340 4.8 10 5 1 1 20 2 alien-interceptor
116 56 36.0 610 7.5 11 4 7 5 34 4 alien-support
117 20 51.0 420 6.0 9 7 3 1 22 2 alien-disruptor
118 26 48.0 480 6.2 10 6 7 2 26 3 alien-raider
119 18 56.0 330 5.0 12 4 1 1 22 3 alien-recon
120 34 45.0 410 6.8 13 4 3 2 28 4 alien-surveyor
121 48 39.0 570 8.2 11 4 3 4 34 4 alien-recovery
122 100 32.0 540 7.4 10 4 3 4 36 4 alien-harvester
124 28 40.0 720 8.6 9 8 15 4 30 2 alien-heavy-combat
125 16 48.0 360 6.2 10 4 3 1 22 3 alien-autonomous-worker
171 22 50.3 410 4.7 9 5 15 1 13 4 finale-upgrade-platform
043 172 22.8 1490 9.7 7 10 15 28 60 4 military-cruiser
081 144 23.3 1480 11.5 7 10 15 24 58 4 capital-escort
123 180 27.7 1660 9.5 8 8 15 18 64 4 alien-capital
"""

RENAMES = {
    "SH018": ("Onager", "onager", "Use a specific wild equid rather than generic Donkey."),
    "SH029": ("Okapi", "okapi", "Remove the second donkey name; retain the mixed-contract role."),
    "SH052": ("Banteng", "banteng", "Use a wild bovine rather than a domestic horse breed."),
    "SH053": ("Caracal Scout", "caracal", "Give the military prototype a predator family instead of a transport breed."),
    "SH058": ("Muskox", "muskox", "Replace a horse breed with a single-word cargo-animal stem."),
    "SH061": ("Saiga", "saiga", "Replace a horse breed with a distinct prey species."),
    "SH079": ("Carabao Freighter", "carabao", "Make cargo carriage explicit; avoid implying a fighter launch bay."),
    "SH092": ("Aurochs", "aurochs", "Use a distinct animal rather than a cattle breed."),
    "SH094": ("Shikra", "shikra", "Use a bird's common name rather than a taxonomic genus."),
    "SH095": ("Shikra Interdictor", "shikra", "Replace unexplained X with the actual EMP-support specialisation."),
    "SH101": ("Cavy Racer", "cavy", "Give the racer a distinct single-word prey stem."),
    "SH129": ("Warthog Escort", "warthog", "Remove the inherited model-number ladder and name its real use."),
    "SH130": ("Marmot Prospector", "marmot", "Remove the unrelated 11 model number."),
    "SH131": ("Warthog Light", "warthog", "Name the actual smaller cargo model."),
    "SH132": ("Warthog Freighter", "warthog", "Name the standard cargo model."),
    "SH133": ("Warthog Tanker", "warthog", "Name the long-range fuel/support conversion."),
    "SH134": ("Warthog Heavy", "warthog", "Name the larger cargo model."),
    "SH155": ("Osprey Support", "osprey", "Remove the unsupported carrier claim; specify a real support loadout."),
}

PROTECTED_NAMES = {
    "SH025": "Peregrine Mk V", "SH054": "Hobby Fighter", "SH062": "Moose Clipper",
    "SH105": "Tapir Shuttle", "SH106": "Tapir Mk II", "SH145": "Kestrel",
    "SH146": "Merlin", "SH147": "Hawk", "SH041": "Serval Fighter",
    "SH007": "Impala Voyager", "SH019": "Gazelle Explorer",
    "SH088": "Springbok Starliner", "SH135": "Javelina", "SH171": "Medusa",
}

MEDUSA_STOCK_FIELDS = {
    'cargo':'cargoTonnes','speed':'maxSpeed','acceleration':'acceleration',
    'energy':'energyCapacity','recharge':'energyRecharge','roll':'roll','pitch':'pitch',
    'yaw':'yaw','shield':'shieldCapacityPerBank','shieldRecharge':'shieldRechargePerBank',
    'fuel':'fuelTankLY','jump':'maxJumpLY','spool':'jumpChargeSeconds',
    'missiles':'missileCapacity','facings':'laserFacingMask',
    'cargoExpansion':'cargoExpansionTonnes','price':'hullPriceCR',
}

FITTING_PROFILES = {
    "trader": ["cargoScoop", "salvageCutter", "surveyArray", "rescueReceiver"],
    "transporter": ["cargoScoop", "salvageCutter", "rescueReceiver", "surveyArray", "auxiliaryFuelTank"],
    "military": ["surveyArray", "salvageCutter", "rescueReceiver", "cargoScoop"],
    "bountyHunter": ["salvageCutter", "cargoScoop", "surveyArray", "rescueReceiver"],
    "pirate": ["cargoScoop", "salvageCutter", "surveyArray"],
    "miner": ["miningLaser", "cargoScoop", "salvageCutter", "surveyArray"],
    "leisure": ["surveyArray", "rescueReceiver", "cargoScoop", "auxiliaryFuelTank"],
    "alien": ["miningLaser", "cargoScoop", "salvageCutter", "surveyArray", "rescueReceiver"],
}

KIT = {
    "mining": ["miningLaser", "cargoScoop"],
    "prospecting": ["miningLaser", "cargoScoop", "surveyArray"],
    "recovery": ["salvageCutter", "cargoScoop", "rescueReceiver"],
    "salvage": ["salvageBeam", "salvageCutter", "cargoScoop"],
    "salvageMining": ["miningLaser", "cargoScoop", "salvageCutter"],
    "survey": ["surveyArray", "flightRecorder"],
    "passenger": ["lifeSupportService", "passengerCabin"],
    "combat": ["combatLaser", "ECM"],
    "support": ["surveyArray", "salvageCutter", "rescueReceiver", "ECM"],
    "emp": ["combatLaser", "ECM", "EMP"],
    "tanker": ["auxiliaryFuelTank", "cargoScoop"],
    "racing": ["flightRecorder"],
    "freight": ["cargoScoop"],
}


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def rows() -> dict[str, dict]:
    result = {}
    for line in ROWS.strip().splitlines():
        vals = line.split()
        sid = "SH" + vals[0]
        assert sid not in result
        cargo, speed, energy, recharge, jump, missiles, mask, crew, equipment, utility = map(float, vals[1:11])
        result[sid] = dict(cargo=int(cargo), speed=speed, energy=int(energy), recharge=recharge,
                           jump=jump, missiles=int(missiles), facings=int(mask), crew=int(crew),
                           equipment=int(equipment), utility=int(utility), niche=vals[11])
    return result


def kit_for(role: str, niche: str) -> tuple[str, list[str]]:
    if niche == "racer": key = "racing"
    elif "emp-interdictor" in niche: key = "emp"
    elif niche == "tanker-support": key = "tanker"
    elif niche in ("command-support", "fleet-support", "alien-support", "utility-service"): key = "support"
    elif "prospect" in niche or niche == "scout-miner": key = "prospecting"
    elif role == "miner" and "salvage" in niche: key = "salvageMining"
    elif role == "miner" or "harvester" in niche or "autonomous-worker" in niche: key = "mining"
    elif any(t in niche for t in ("salvage", "scaveng")): key = "salvage"
    elif any(t in niche for t in ("rescue", "recovery", "boarding")): key = "recovery"
    elif any(t in niche for t in ("survey", "recon", "explor", "voyag", "expedition")): key = "survey"
    elif any(t in niche for t in ("liner", "passenger", "dropship")): key = "passenger"
    elif role in ("military", "bountyHunter", "pirate", "alien"): key = "combat"
    else: key = "freight"
    return key, KIT[key].copy()


def value(v):
    if isinstance(v, bool): return str(v).lower()
    if isinstance(v, str): return json.dumps(v, ensure_ascii=True)
    if isinstance(v, (list, tuple)): return "[" + ", ".join(value(x) for x in v) + "]"
    if v is None: raise ValueError("TOML has no null")
    return repr(v)


def toml(document):
    lines = ["# Authored design proposal v2. Not installed or playtested."]
    for key, val in document.items():
        if not isinstance(val, dict): lines.append(f"{key} = {value(val)}")
    for key, val in document.items():
        if isinstance(val, dict):
            lines += ["", f"[{key}]"]
            lines += [f"{k} = {value(v)}" for k, v in val.items()]
    return "\n".join(lines) + "\n"


def target_shape(s, tune, dimensions):
    """Explicit design targets; never an assertion about active calibration."""
    if dimensions:
        return [round(dimensions[k], 5) for k in ("width", "height", "length")], "retained-authored-metres"
    role = s["role"]
    c = tune.get("cargo", 0)
    if s["isCapital"]: dims = [120.0, 64.0, 180.0]
    elif role == "transporter":
        dims = [44.0, 20.0, 76.0] if c < 400 else ([68.0, 30.0, 110.0] if c < 800 else [96.0, 38.0, 150.0])
    elif role == "trader": dims = [28.0, 11.0, 40.0]
    elif role == "miner": dims = [30.0, 16.0, 46.0]
    elif role == "leisure" and c >= 80: dims = [36.0, 18.0, 64.0]
    elif role == "alien": dims = [30.0, 12.0, 38.0]
    elif role == "capsule": dims = [4.0, 3.0, 6.0]
    elif role == "station": dims = [250.0, 250.0, 300.0]
    elif role == "platform": dims = [160.0, 80.0, 220.0]
    elif role == "other": dims = [8.0, 4.0, 12.0]
    else: dims = [22.0, 8.0, 30.0]
    return dims, "new-layout-target-estimate; preserve any later verified active calibration"


def make_record(s, source, tuning, workspace):
    sid = s["id"]
    tune = tuning.get(sid, {})
    old = s["stats"]
    name, family, reason = RENAMES.get(sid, (s["name"], s["family"], "Retain the accepted animal stem and identity."))
    path = workspace / source["geometryFile"]
    geometry = tomllib.loads(path.read_text())
    intent = geometry.get("proposal", {}).get("intent", "Retain indexed original silhouette.")
    dims, dimensional_basis = target_shape(s, tune, source.get("dimensions"))
    capital = s["isCapital"]
    record = {
        "schema": "l337.fleet-design/2", "id": sid, "name": name, "family": family,
        "classification": s["role"], "objectKind": s["objectKind"], "capital": capital,
        "origin": "larvaal" if s["role"] == "alien" or sid == "SH162" else "human",
        "primaryUse": tune.get("niche", {"station": "station-services", "platform": "weapons-platform", "capsule": "escape", "other": "mission-probe"}.get(s["role"], "mission-object")),
        "decisionStatus": "new-authored-design; implementation-and-playtesting-pending",
        "access": {
            "playerFlyable": bool(s["playerFlyable"] and not capital) or sid == "SH163",
            "purchasePolicy": "blueprintFabrication" if sid == "SH163" else s["purchasePolicy"],
            "discoveryPolicy": "dock" if s["objectKind"] == "station" else ("encounter-then-player-EMP-disable-and-authorised-physical-salvage" if s["purchasePolicy"] in ("blueprintFabrication","plughQuestFabrication") or sid == "SH163" else "existing-explicit-native-gallery-milestone; no-purchase-right"),
            "missionGate": "Q01-full-clue-trail-EMP-salvage-lattice-receiving-PLUGH" if sid == "SH171" else "none",
            "normalPurchaseRequiresCrew": not capital and sid != "SH040",
        },
        "source": {"previousName": s["name"], "statsFile": "fleet-specs/" + sid + ".toml",
                   "statsSHA256": s["sha256"], "geometryFile": source["geometryFile"],
                   "geometrySHA256": source["geometrySHA256"], "nameDecision": reason},
        "geometry": {
            "basis": "retain-original-family-and-palette; implement-listed-revisions",
            "originalIntent": intent,
            "dimensionsWHLMetres": dims, "dimensionStatus": dimensional_basis,
            "scaleRule": "Verify source units and active per-ID calibration before any geometry rescale.",
            "cockpitRule": "Opaque connected structural support under all glazing; verify in every view.",
            "surfaceRule": "smooth-jade-organic" if s["role"] == "alien" and sid != "SH171" else ("retained-organic-medusa" if sid == "SH171" else "sparse-recessed-seamless-human-panels"),
            "variantFeature": tune.get("niche", s["role"]),
            "nativeFaceLimit": 512,
        },
    }
    if sid=='SH123':
        record['geometry'].update({
            'basis':'retain-current-selected-branding-display-source; historical geometry is audit provenance only',
            'currentAcceptedDisplaySource':'branding-proposal/selected-ship.toml',
            'currentAcceptedDisplaySourceSHA256':'2179227760376ed17b276153cb7cb20894f4f1bad5bf48e339b7dc874f70fe69',
            'currentAcceptedDisplayResource':'Sources/L337Core/Resources/OriginalFleetShowroomModels/SH123.json',
            'currentAcceptedDisplayResourceSHA256':'f6648d12e2a476092088c7a79c8e1220b272f6370fddfde779f97db7d216f163',
            'currentAcceptedDisplayCommit':'e10c06e45c36df450b0d60074c8d2faef6b9cd18',
            'displayIsPhysicalCalibration':False,
            'nativeRule':'Separately author/calibrate native LOD and clearance retaining the selected appearance; display source grants no physical scale, inertia, purchase or activation.',
        })
        record['geometry']['originalIntent']='Historical audit only: '+intent
    if old or sid == "SH163":
        base = old or dict(cargo=36, speed=44., acceleration=14., energy=410, recharge=5.4, roll=1.1,
                           pitch=1., yaw=.9, shield=300, shieldRecharge=1.8, fuel=140, jump=10,
                           spool=15, missiles=6, facings=7, cargoExpansion=16, price=330000)
        if sid == "SH040":
            t = dict(cargo=0, speed=18., energy=70, recharge=.6, jump=0., missiles=0, facings=0, crew=1, equipment=0, utility=0, niche="escape")
        else: t = tune
        # Endurance roles exchange acceleration/turning for sustained work. Interceptors do the reverse.
        handling = 1.12 if any(x in t["niche"] for x in ("interceptor", "pursuit", "racer")) else (.86 if any(x in t["niche"] for x in ("heavy", "liner", "hauler", "gunship")) else 1.)
        price = round((18000 + t["cargo"]*220 + t["energy"]*320 + t["speed"]*1800
                       + t["recharge"]*9000 + t["jump"]*5000 + t["equipment"]*600
                       + t["utility"]*4000 + t["missiles"]*3500) / 1000) * 1000
        if capital or sid == "SH040": price = 0
        fuel = max(base["fuel"] / 10, t["jump"] + 2)
        if sid == "SH040": fuel = 0
        if sid == "SH133": fuel = 19
        record["performance"] = {
            "cargoTonnes": t["cargo"], "maxSpeed": t["speed"],
            "acceleration": round(base["acceleration"]*handling, 2),
            "energyCapacity": t["energy"], "energyRecharge": t["recharge"],
            "roll": round(base["roll"]*handling, 3), "pitch": round(base["pitch"]*handling, 3), "yaw": round(base["yaw"]*handling, 3),
            "shieldCapacityPerBank": base["shield"],
            "shieldRechargePerBank": base["shieldRecharge"],
            "fuelTankLY": fuel, "maxJumpLY": t["jump"], "jumpChargeSeconds": base["spool"],
            "missileCapacity": t["missiles"], "laserFacingMask": t["facings"],
            "cargoExpansionTonnes": base["cargoExpansion"], "hullPriceCR": price,
        }
        if sid=='SH171':
            flagship=json.loads((Path(__file__).resolve().parent/'references/salvage/MEDUSA-FLAGSHIP.json').read_text())
            fields=MEDUSA_STOCK_FIELDS
            stock=flagship['configurations']['catalogueBase']['restoredStockValues']
            for source_key,field in fields.items():
                baseline=stock[source_key]
                record['performance'][field]=baseline/10 if source_key=='fuel' else baseline
            record['source']['medusaFlagshipSource']='references/salvage/MEDUSA-FLAGSHIP.json'
            record['medusaConfigurations']={
                'configurationKeys':list(flagship['configurations']),
                'catalogueBase':'unupgraded baseline; greatest upgrade potential, not all leading stock statistics',
                'missionInstance':'quest-limited; separately authored real finite equipment; beatable; never inherit player maximum',
                'missionFullyUpgraded':False,'plughShowroom':'paid stock fit explicitly listed in quote; upgrades purchased afterwards',
                'purchaseGrantsMaximumFit':False,'fullyUpgradedPlayerRequirement':'most powerful legal fully upgraded ship at matched external contributions and condition',
                'stockEquipmentBudget':13,'candidatePaidExpansionBudget':32,
                'expansionStatus':'proposal only; requires real compatible paid upgrade and physical fitting contract',
                'completeLoadoutPowerComparison':'pending; stock-only comparison is not proof',
            }
            record['candidatePlayerUpgradeTargets']={
                'status':'candidate fully upgraded targets only; not stock, mission, approved upgrade nodes or verified superiority',
                **{fields[k]:(v['candidateFullyUpgradedMedusa']/10 if k=='fuel' else v['candidateFullyUpgradedMedusa']) for k,v in flagship['priorNumericalTargets']['metrics'].items()},
            }
        crew = t["crew"]
        record["accommodation"] = {
            "basis": "new-per-hull-design-layout-estimate; not-historical-crew-or-E01",
            "minimumOperatingCrewIncludingCommander": crew, "intrinsicCrewPlaces": crew,
            "nativeAutonomous": sid == "SH125", "nativeCrew": 0 if sid == "SH125" else crew,
            "playerConversionCrew": crew, "initialPurchasedCabins": 0,
            "cabinModuleMassTonnes": 5, "cabinModuleEquipmentUnits": 1,
            "maximumPhysicalCabinModules": t["cargo"]//5,
            "holdBasis": "Cargo is usable empty hold after intrinsic crew/core structure; purchased modules consume this hold.",
        }
        key, required = kit_for(s["role"], t["niche"])
        compatible = FITTING_PROFILES.get(s["role"], [])[:]
        if t['utility']>=3 and 'salvageCutter' in compatible and 'cargoScoop' in compatible:
            compatible.append('salvageBeam')
        if sid=='SH171': compatible.append('auxiliaryFuelTank')
        if key in ("mining", "prospecting") and "miningLaser" not in compatible: compatible.append("miningLaser")
        if "salvage" in t["niche"] and "salvageCutter" not in compatible: compatible.append("salvageCutter")
        if sid == "SH133" and "auxiliaryFuelTank" not in compatible: compatible.append("auxiliaryFuelTank")
        if sid == "SH171": required = ["combatLaser", "ECM", "EMP"]
        if sid == "SH040": required, compatible = [], []
        record["fitting"] = {
            "equipmentBudgetUnits": t["equipment"], "utilityMounts": t["utility"],
            "compatibleUtilities": compatible, "recommendedRoleKit": required,
            "roleKitIncludedInBareHull": False,
            "passengerCabinGrades": ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"] if sid != "SH040" else [],
            "externalMissilePylons": s["role"] != "alien" and sid != "SH145" and t["niche"] in ("assault-fighter", "strike-fighter", "missile-strike", "hammerhead-strike", "heavy-raider", "missile-pursuit"),
            "missileStorage": "internal-organic" if s["role"] == "alien" else ("internal" if sid == "SH145" else "modelled-mounts-and-magazine"),
        }
        if sid in ("SH046", "SH012", "SH035", "SH088", "SH093", "SH105", "SH106", "SH166"):
            record["fitting"]["recommendedCabinGrade"] = "standard" if sid == "SH046" else ("singleStateroom" if sid == "SH093" else "economy")
            record["fitting"]["recommendedCabinModules"] = {"SH046": 4,"SH012": 16,"SH035": 8,"SH088": 20,"SH093": 12,"SH105": 20,"SH106": 24,"SH166": 16}[sid]
        if record['access']['purchasePolicy'] in ('blueprintFabrication','plughQuestFabrication'):
            record['acquisition']={
                'controllingWorkstream':'WS-SALVAGE-01 / M08.SALVAGE.EMP-01',
                'method':'commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop',
                'laserMissilePreparationMandatory':False, 'destructionGrantsBlueprint':False,
                'disableAloneGrantsBlueprint':False, 'sampleMassTonnes':0.05,
                'sampleMassStatus':'researcher-proposed-balance; physical intake still required',
                'beamRequirement':'Power and reach depend on calibrated target volume, carried mass and surface distance; unknown until physical contract exists.',
                'EMPBank':'Separate physical finite capacitor; pulse power, stored shots and recharge are independent paid axes.',
                'policySource':'references/salvage/SALVAGE-ACQUISITION.json',
            }
            if sid=='SH171':
                record['acquisition']['questActorCrew']=0
                record['acquisition']['sample']='original 50kg outer reconstruction lattice; sovereign core protected'
                record['acquisition']['receiving']='same intact lattice consumed by later PLUGH AI receiving; story/fabrication right together; paid ship optional'
                record['acquisition']['retry']='same unlocked cradle, new legitimate construct after actual loss; retain clues/trail; no duplicate old sample'
                record['acquisition']['loan']='no-fee/no-deposit compatible real service hull, crew and tools when needed; no permanent ownership grant'
    else:
        record["environment"] = {"playerCrewRequired": False, "purchasePolicy": "never", "physicalService": record["primaryUse"]}
    return record


def write_ai(out, records):
    shapes = {
        "TN-01": ("SH004", "Tithe Scout", "scout-and-escort", 4,
                  [[0,0,0,8,4,18],[-6,0,-2,4,6,12],[6,0,-2,4,6,12],[0,3,6,6,2,4]],
                  "Two armoured power blocks bracket a recessed sensor spine; weapon apertures face forward."),
        "TN-02": ("SH001", "Tithe Utility", "resource-transfer", 2,
                  [[0,0,0,6,6,30],[-8,0,0,10,8,22],[8,0,0,10,8,22],[0,-5,4,8,2,12]],
                  "An exposed service spine carries two rectangular cargo racks and an underside transfer throat."),
        "TN-03": ("SH005", "Tithe Transport", "bulk-resource-haulage", 2,
                  [[0,0,0,12,12,80]] + [[x,0,z,18,18,15] for x in (-16,16) for z in (-27,-9,9,27)] + [[x,0,z,3,4,8] for x in (-6.5,6.5) for z in (-27,-9,9,27)] + [[0,7,-15,8,6,12],[0,12,-15,28,8,16]],
                  "Four socketed machinery tiers sit around a straight bus; lateral radiator slabs and rear thrusters remain clear."),
    }
    result = []
    for vid,(parent,name,use,count,blocks,brief) in shapes.items():
        p = records[parent]
        doc = {"schema":"l337.fleet-design-variant/2", "id":vid,"name":name,
               "parentHullID":parent,"faction":"tithe-network","primaryUse":use,
               "cataloguePolicy":"variant-under-parent; separate-appearance-and-blueprint-evidence",
               "performanceSource":"ships/"+parent+".toml", "missionReserveCount":count,
               "design":{"brief":brief,"style":"blocky-functional-autonomous","units":"metres",
                         "boxComponentsXYZWHL":[[float(v) for v in b] for b in blocks],
                         "cockpit":False,"windows":False,"humanBridge":False,
                         "palette":["gunmetal","oxidised-steel","amber-status"],
                         "detail":"Service panels, cable trunks, radiators, bolt access and keyed docking sockets only.",
                         "collisionRule":"Separate collision and service aperture bounds; no silhouette-only collision box."},
               "conversion":{"nativeCrew":0,"crewRetrofitRequiredForPlayer":True,
                             "retrofitService":"PLUGH","retrofitPriceCR":round(p["performance"]["hullPriceCR"]*.15/1000)*1000,
                             "retrofitEquipmentUnits":2+math.ceil(p["accommodation"]["minimumOperatingCrewIncludingCommander"]/4),
                             "retrofitHoldTonnes":5*p["accommodation"]["minimumOperatingCrewIncludingCommander"],
                             "retrofitCrew":p["accommodation"]["minimumOperatingCrewIncludingCommander"],
                             "rogueAISoftwareTransferred":False,"blueprint":"commander-EMP-disable-and-lawful-physical-salvage-of-this-actual-variant"}}
        (out/"ai"/(vid+".toml")).write_text(toml(doc))
        result.append(doc)
        # Deliberately simple authoring diagram of the specified box assemblies, not a ship portrait.
        rects=[]
        for x,y,z,w,h,l in blocks:
            rects.append(f'<rect x="{250+x*3-w*1.5}" y="{230-z*3-l*1.5}" width="{w*3}" height="{l*3}" fill="#42494f" stroke="#e6ad4b"/>')
        svg='<svg xmlns="http://www.w3.org/2000/svg" width="500" height="500" viewBox="0 0 500 500"><rect width="500" height="500" fill="#101820"/><g>'+''.join(rects)+'</g><text x="20" y="30" fill="white">'+name+' / top / +Z forward</text><text x="20" y="470" fill="white">Assembly brief; not a rendered model or acceptance proof</text></svg>'
        (out/"ai"/(vid+".svg")).write_text(svg)
    return result


def author(workspace: Path, out: Path):
    manifest_path = workspace/"fleet-specs/manifest.json"
    index_path = workspace/"fleet-completion-20261019/delivery-index.json"
    manifest = json.loads(manifest_path.read_text())
    index = {s["id"]:s for s in json.loads(index_path.read_text())["ships"]}
    tuning=rows()
    for d in ["ships","ai"]: (out/d).mkdir(parents=True,exist_ok=True)
    records={}; changes=[]
    for s in manifest["ships"]:
        source=index[s["id"]]
        assert digest(workspace/source["statsFile"]) == source["statsSHA256"]
        assert digest(workspace/source["geometryFile"]) == source["geometrySHA256"]
        rec=make_record(s,source,tuning,workspace)
        records[s["id"]]=rec
        (out/"ships"/(s["id"]+".toml")).write_text(toml(rec))
        changes.append({"id":s["id"],"oldName":s["name"],"newName":rec["name"],"nameReason":rec["source"]["nameDecision"],
                        "previousGame":s["stats"],"proposedPerformance":rec.get("performance"),
                        "previousAccess":{"flyable":s["playerFlyable"],"purchasePolicy":s["purchasePolicy"]},
                        "proposedAccess":rec["access"],"newPrimaryUse":rec["primaryUse"],
                        "proposedAccommodation":rec.get("accommodation"),"proposedFitting":rec.get("fitting"),
                        "proposedAcquisition":rec.get("acquisition"),"proposedGeometryContract":rec["geometry"],
                        "geometryActions":["Apply GEOMETRY.md and per-ID variant brief; retain source identity, units and palette."]})
    ai=write_ai(out,records)
    (out/"changes.json").write_text(json.dumps(changes,indent=2)+"\n")
    grouped=collections.defaultdict(list)
    for rec in records.values(): grouped[rec["classification"]].append(rec)
    lines=["# Fleet v2 catalogue", "", "Authored design targets. This is not a playable-delivery or measured-balance claim.", "", "Base holds are tonnes; fuel and range are LY. Prices are whole credits. Role kits and purchased cabins are not free.", ""]
    for role,ships in sorted(grouped.items()):
        lines += ["## "+role+" ("+str(len(ships))+")", "", "| ID | Name | Use | Hold t | Speed u/s | Energy / recharge | Jump LY | Missiles | Crew | Equipment / utility |", "| --- | --- | --- | ---: | ---: | --- | ---: | ---: | ---: | --- |"]
        for rec in ships:
            v=rec.get("performance"); a=rec.get("accommodation",{});f=rec.get("fitting",{})
            vals=[rec["id"],f'[{rec["name"]}](ships/{rec["id"]}.toml)',rec["primaryUse"]]
            vals += [str(v["cargoTonnes"]),str(v["maxSpeed"]),str(v["energyCapacity"])+" / "+str(v["energyRecharge"]),str(v["maxJumpLY"]),str(v["missileCapacity"]),str(a["minimumOperatingCrewIncludingCommander"]),str(f["equipmentBudgetUnits"])+" / "+str(f["utilityMounts"])] if v else ["N/A"]*7
            lines.append("| "+" | ".join(vals)+" |")
        lines += [""]
    lines += ["## Tithe mission conversions", "", "171 base hulls remain indexed. These three autonomous conversions are variants, not three silently substituted base hulls.", ""]
    lines += [f'- [{d["name"]}](ai/{d["id"]}.toml): {d["primaryUse"]}, parent {d["parentHullID"]}, reserve {d["missionReserveCount"]}.' for d in ai]
    (out/"CATALOGUE.md").write_text("\n".join(lines)+"\n")
    names=["# Naming decisions", "", "See [the naming policy](NAMING.md). These changes are proposals from this request, not claims of earlier user approval.", "", "| ID | Previous | Proposed | Reason |", "| --- | --- | --- | --- |"]
    names += [f'| {sid} | {records[sid]["source"]["previousName"]} | {name} | {reason} |' for sid,(name,family,reason) in sorted(RENAMES.items())]
    (out/"NAME-CHANGES.md").write_text("\n".join(names)+"\n")
    input_sources={"fleetManifestSHA256":digest(manifest_path),"deliveryIndexSHA256":digest(index_path),"sharedChat":"https://chatgpt.com/share/6ae4555e-326c-83ed-8736-f0d1f16d4a60?ogimg=plain","sharedChatTreatment":"Reference inspiration and critique; third-party illustrative images are not owned ship assets.","sharedChatRetrievedUTCDate":"2026-10-30","sharedChatHTMLSHA256":"56d9d5585b98ee3ef4bba0730681972019ca07c74f7ddcd2a8088b09a6cc4e8e",
                   "salvageResearcherCommit":"a91c899589e226c01adb180c4bee6b162cb0ee67",
                   "salvageContractSHA256":"7c0d9f9067d69f0ebfc562f8801046d395e7004420729a3a124e2f3a26e2ef04",
                   "medusaFlagshipSHA256":"0e2e6639721f77392cdc5566a0df3b9eb41b038d61564d7753b7f64d760b8771",
                   "medusaClarificationPacketSHA256":"ae837946fe3ddd5e8af0cfa07bdb25ab90a35878ab132c75efedd9f602e03118"}
    (out/"provenance.json").write_text(json.dumps(input_sources,indent=2)+"\n")
    return records


def validate(out):
    docs={p.stem:tomllib.loads(p.read_text()) for p in sorted((out/"ships").glob('SH*.toml'))}
    assert digest(out/'references/salvage/SALVAGE-ACQUISITION.json')=='7c0d9f9067d69f0ebfc562f8801046d395e7004420729a3a124e2f3a26e2ef04'
    assert digest(out/'references/salvage/salvage-mission-migration.json')=='7c189377a879cf2ea266dd0025cbade85002d5318199d04abafc06b28e68340d'
    assert digest(out/'references/salvage/MEDUSA-FLAGSHIP.json')=='0e2e6639721f77392cdc5566a0df3b9eb41b038d61564d7753b7f64d760b8771'
    assert digest(out/'references/salvage/medusa-loadout-frozen-packet.json')=='ae837946fe3ddd5e8af0cfa07bdb25ab90a35878ab132c75efedd9f602e03118'
    assert set(docs)=={f'SH{n:03}' for n in range(1,172)}
    profiles=collections.defaultdict(list)
    equipment_units={'miningLaser':1,'cargoScoop':1,'salvageCutter':1,'salvageBeam':3,'surveyArray':2,'rescueReceiver':2,'auxiliaryFuelTank':2,'flightRecorder':1,'passengerCabin':1,'lifeSupportService':0,'combatLaser':1,'ECM':1,'EMP':2}
    utility_devices={'miningLaser','cargoScoop','salvageCutter','salvageBeam','surveyArray','rescueReceiver'}
    for sid,d in docs.items():
        assert d['id']==sid
        if sid in PROTECTED_NAMES: assert d['name']==PROTECTED_NAMES[sid]
        if 'performance' not in d: continue
        p=d['performance'];a=d['accommodation'];f=d['fitting']
        assert type(a['initialPurchasedCabins']) is int and a['initialPurchasedCabins']==0, (sid,'no-free-cabins')
        assert f['roleKitIncludedInBareHull'] is False, (sid,'no-free-role-kit')
        assert all(isinstance(v,(int,float)) and math.isfinite(v) and v>=0 for v in p.values())
        assert p['maxJumpLY']<=p['fuelTankLY']
        assert a['intrinsicCrewPlaces']>=a['minimumOperatingCrewIncludingCommander']
        assert f['utilityMounts']<=f['equipmentBudgetUnits']
        role_kit=f['recommendedRoleKit']
        assert sum(x in utility_devices for x in role_kit)<=f['utilityMounts'], (sid,'utility fit')
        assert all(x in f['compatibleUtilities'] for x in role_kit if x in utility_devices), (sid,'unsupported utility')
        assert 4+sum(equipment_units[x] for x in role_kit)<=f['equipmentBudgetUnits'] or sid=='SH040', (sid,'equipment fit')
        if d['classification']=='trader': assert p['cargoTonnes']>=25
        if d['classification']=='transporter': assert p['cargoTonnes']>=150
        if sid!='SH040': assert p['laserFacingMask']&1 and p['missileCapacity']>=4
        if d['capital']: assert d['access']['purchasePolicy']=='never' and p['hullPriceCR']==0
        if d['access']['purchasePolicy'] not in ('never',): assert p['hullPriceCR']>0
        if d['access']['purchasePolicy'] in ('blueprintFabrication','plughQuestFabrication'):
            assert d['acquisition']['destructionGrantsBlueprint'] is False
            assert d['acquisition']['disableAloneGrantsBlueprint'] is False
            assert 'EMP' in d['access']['discoveryPolicy']
        if 'recommendedCabinModules' in f:
            assert f['recommendedCabinModules']*5<=p['cargoTonnes']
            noncabin=sum(equipment_units[x] for x in role_kit if x!='passengerCabin')
            assert f['recommendedCabinModules']+4+noncabin<=f['equipmentBudgetUnits']
        signature=tuple((k,v) for k,v in p.items() if k!='hullPriceCR')
        profiles[signature].append(sid)
    duplicates=[ids for ids in profiles.values() if len(ids)>1]
    assert not duplicates, duplicates
    assert len({d['name'].casefold() for d in docs.values()})==171
    assert docs['SH163']['access']['purchasePolicy']=='blueprintFabrication'
    assert docs['SH171']['access']['missionGate'].startswith('Q01-full')
    assert docs['SH171']['acquisition']['questActorCrew']==0
    assert docs['SH171']['acquisition']['sampleMassTonnes']==0.05
    medusa=docs['SH171']['performance']
    medusa_reference=json.loads((out/'references/salvage/MEDUSA-FLAGSHIP.json').read_text())
    config_keys=set(medusa_reference['configurations'])
    assert config_keys=={'catalogueBase','missionInstance','plughShowroom','fullyUpgradedPlayer'}
    assert set(docs['SH171']['medusaConfigurations']['configurationKeys'])==config_keys and len(docs['SH171']['medusaConfigurations']['configurationKeys'])==len(config_keys), 'Medusa configuration keys'
    stock=medusa_reference['configurations']['catalogueBase']['restoredStockValues']
    assert set(stock)==set(MEDUSA_STOCK_FIELDS) and len(stock)==17
    expected={field:(stock[key]/10 if key=='fuel' else stock[key]) for key,field in MEDUSA_STOCK_FIELDS.items()}
    assert medusa==expected, ('Medusa all17 stock fields', {k:(expected[k],medusa.get(k)) for k in expected if medusa.get(k)!=expected[k]})
    assert docs['SH171']['medusaConfigurations']['missionFullyUpgraded'] is False
    assert docs['SH171']['medusaConfigurations']['purchaseGrantsMaximumFit'] is False
    assert docs['SH171']['medusaConfigurations']['stockEquipmentBudget']==13
    assert docs['SH171']['medusaConfigurations']['candidatePaidExpansionBudget']==32
    assert docs['SH171']['accommodation']['minimumOperatingCrewIncludingCommander']==1
    assert docs['SH171']['fitting']['equipmentBudgetUnits']==13
    assert docs['SH123']['source']['geometrySHA256']=='a430c5e8946db1d2f27d5030ae3f245f0838e52f2dadf1409323a16fc1c67499'
    assert docs['SH123']['geometry']['currentAcceptedDisplaySourceSHA256']=='2179227760376ed17b276153cb7cb20894f4f1bad5bf48e339b7dc874f70fe69'
    assert docs['SH123']['geometry']['currentAcceptedDisplayResourceSHA256']=='f6648d12e2a476092088c7a79c8e1220b272f6370fddfde779f97db7d216f163'
    assert docs['SH123']['geometry']['displayIsPhysicalCalibration'] is False
    assert docs['SH145']['fitting']['externalMissilePylons'] is False
    assert all(not d['fitting']['externalMissilePylons'] for d in docs.values() if d['classification']=='alien')
    ai=[tomllib.loads(p.read_text()) for p in (out/'ai').glob('*.toml')]
    assert len(ai)==3 and sum(x['missionReserveCount'] for x in ai)==8
    assert {x['name'] for x in ai}=={'Tithe Scout','Tithe Utility','Tithe Transport'}
    assert {x['parentHullID'] for x in ai}=={'SH001','SH004','SH005'}
    for variant in ai:
        parent=docs[variant['parentHullID']]; conversion=variant['conversion']
        assert parent['performance']['cargoTonnes']>=conversion['retrofitHoldTonnes']
        assert parent['fitting']['equipmentBudgetUnits']>=conversion['retrofitEquipmentUnits']+4
        blocks=variant['design']['boxComponentsXYZWHL']
        assert all(len(b)==6 and all(math.isfinite(v) for v in b) and all(v>0 for v in b[3:]) for b in blocks)
        connected={0}
        while True:
            more={j for j,b in enumerate(blocks) if any(all(abs(b[k]-blocks[i][k])<=(b[k+3]+blocks[i][k+3])/2+1e-8 for k in range(3)) for i in connected)}
            if more<=connected:break
            connected|=more
        assert len(connected)==len(blocks), (variant['id'],'disconnected assembly envelopes')
    partitions={'B':[],'C':[],'D':[],'E':[]}
    for sid,d in docs.items():
        role=d['classification']
        track='B' if role=='trader' else ('C' if role in ('transporter','miner','leisure') else ('D' if role in ('military','bountyHunter','pirate') and not d['capital'] else 'E'))
        partitions[track].append(sid)
    assert [len(partitions[x]) for x in ('B','C','D','E')]==[26,47,72,26]
    (out/'PARTITIONS.json').write_text(json.dumps({'status':'proposed-scope-only; Root owns actual ledger assignments','baseHulls':partitions,'sharedSchemaOwner':'A','presentationOwner':'F','titheVariantsOwner':'E'},indent=2)+'\n')
    report={"scope":"Design data validation only; no runtime, rendering, collision, balance, native test or release proof.","baseHulls":len(docs),"performanceRecords":sum('performance' in x for x in docs.values()),"uniqueFunctionalProfiles":len(profiles),"duplicateFunctionalProfiles":duplicates,"renames":len(RENAMES),"autonomousVariants":len(ai),"finiteTitheReserve":8,"medusaConfigurationCount":len(config_keys),"medusaExactStockFieldsChecked":len(expected),"medusaMaximumGrantedToMissionOrPurchase":False,"fullyUpgradedComparativePowerVerified":False,"equipmentFitModel":"proposal planning weights only; native device/socket/mass/power bindings require EQUIPMENT-MAPPING.md","result":"PASS"}
    (out/'VALIDATION.json').write_text(json.dumps(report,indent=2)+'\n')
    entries=[]
    for p in sorted(out.rglob('*')):
        if p.is_file() and p.name!='MANIFEST.json': entries.append({"path":str(p.relative_to(out)),"sha256":digest(p)})
    (out/'MANIFEST.json').write_text(json.dumps({"schema":"l337.fleet-design-delivery/2","files":entries},indent=2)+'\n')
    print(json.dumps(report))


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-workspace',type=Path)
    parser.add_argument('--check',action='store_true')
    args=parser.parse_args(); output=Path(__file__).resolve().parent
    if not args.check:
        if args.source_workspace is None: parser.error('--source-workspace is required for authoring')
        author(args.source_workspace,output)
    validate(output)
