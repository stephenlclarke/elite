"""Read/write the restricted catalogue schema using standard TOML syntax.

Runtime decoding uses TOMLDecoder; authoring checks use Python's TOML parser.
There is no regex or hand-written TOML parser.
"""
import json
import importlib.util
import tomllib
from pathlib import Path

SHIP_FOLDER = Path('Sources/L337Core/Resources/Ships')
_balance_spec = importlib.util.spec_from_file_location('catalogue_balance', Path(__file__).with_name('catalogue-balance.py'))
catalogue_balance = importlib.util.module_from_spec(_balance_spec)
_balance_spec.loader.exec_module(catalogue_balance)


def value(item):
    """Encode JSON-compatible catalogue values as TOML inline values."""
    if isinstance(item, dict):
        return '{ ' + ', '.join(json.dumps(k)+ ' = '+value(v) for k,v in item.items() if v is not None) + ' }'
    if isinstance(item, list):
        return '[' + ', '.join(value(v) for v in item) + ']'
    return json.dumps(item, ensure_ascii=True, allow_nan=False)


def write_ship(path, ship):
    """Keep editable game specs and actual geometry in one self-contained file."""
    ship = catalogue_balance.apply_balance(ship, catalogue_balance.load_balances())
    lines = ['# Authoritative ship definition. See docs/SHIP-FILES.md.']
    for key,item in ship.items():
        if key not in {'catalogue','game','design','nativeDesign','nativeCombat','profiles'} and item is not None:
            lines.append(key+' = '+value(item))
    for table in ['catalogue','game','design','nativeDesign','nativeCombat']:
        if table not in ship:continue
        lines.extend(['','['+table+']'])
        for key,item in ship[table].items():
            if key in {'vertices','faces'}:
                lines.append(key+' = [\n'+''.join('  '+value(row)+',\n' for row in item)+']')
            elif item is not None:lines.append(key+' = '+value(item))
    for profile in ship['profiles']:
        lines.extend(['','[[profiles]]'])
        for key,item in profile.items():lines.append(key+' = '+value(item))
    text='\n'.join(lines)+'\n'
    assert tomllib.loads(text)=={k:v for k,v in ship.items() if v is not None}
    path.write_text(text)


def read_ships(folder=SHIP_FOLDER):
    """Reject missing IDs, duplicate identities and mismatched filenames."""
    ships=[tomllib.loads(p.read_text()) for p in sorted(folder.glob('*.toml'))]
    assert ships and len({s['id'] for s in ships})==len(ships)
    for ship in ships:
        assert (folder/(ship['id']+'.toml')).is_file()
        assert ship['design']['vertices'] and ship['design']['faces']
    return ships
