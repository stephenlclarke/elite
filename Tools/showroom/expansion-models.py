"""Import complete, source-hashed Oolite assemblies without activating source scripts."""
import hashlib
import json
import math
import subprocess
import zipfile
from pathlib import Path


def source_definitions(archive):
    """Parse actual source ship dictionaries with macOS's OpenStep/XML plist reader."""
    names = [n for n in archive.namelist() if n.lower().endswith('/config/shipdata.plist') or n.lower() == 'config/shipdata.plist']
    assert len(names) == 1, names
    data = archive.read(names[0])
    parsed = subprocess.run(['plutil', '-convert', 'json', '-o', '-', '--', '-'],
                            input=data, capture_output=True, check=True)
    return json.loads(parsed.stdout), {names[0]: hashlib.sha256(data).hexdigest()}


def resolved(key, definitions, seen=()):
    """Resolve like_ship inheritance, retaining explicit child overrides."""
    assert key not in seen, 'Cyclic source inheritance: '+key
    raw = definitions[key]
    parent = raw.get('like_ship')
    return (resolved(parent, definitions, seen+(key,)) if parent else {}) | raw


def subentity(part):
    """Accept both legacy strings and dictionary forms; flashers have no hull geometry."""
    if isinstance(part, str):
        values = part.split()
        if values[0] == '*FLASHER*':
            return None
        assert len(values) == 8, part
        return dict(subentity_key=values[0], position=values[1:4], orientation=values[4:8])
    return None if part.get('type') == 'flasher' else part


def append_component(result, child, part):
    """Apply source quaternion and translation before one final whole-assembly normalization."""
    orientation = part.get('orientation', [1, 0, 0, 0])
    q = [float(v) for v in (orientation.split() if isinstance(orientation, str) else orientation)]
    norm = math.sqrt(sum(v*v for v in q))
    assert len(q) == 4 and norm > 0
    w, x, y, z = [v/norm for v in q]
    position = part.get('position', [0, 0, 0])
    pos = [float(v) for v in (position.split() if isinstance(position, str) else position)]
    assert len(pos) == 3
    offset = len(result['vertices'])
    for vx, vy, vz in child['vertices']:
        vz = -vz
        rx = (1-2*y*y-2*z*z)*vx + (2*x*y-2*z*w)*vy + (2*x*z+2*y*w)*vz
        ry = (2*x*y+2*z*w)*vx + (1-2*x*x-2*z*z)*vy + (2*y*z-2*x*w)*vz
        rz = (2*x*z-2*y*w)*vx + (2*y*z+2*x*w)*vy + (1-2*x*x-2*y*y)*vz
        result['vertices'].append([rx+pos[0], ry+pos[1], -(rz+pos[2])])
    result['faces'].extend([[v+offset for v in face] for face in child['faces']])
    result['components'] += child['components']


def assembly(key, definitions, model_reader, seen=()):
    """Fail closed on missing geometry rather than quietly dropping a wing or engine."""
    assert key not in seen, 'Cyclic subentity graph: '+key
    raw = resolved(key, definitions)
    result = model_reader(raw['model'])
    result['components'] = [key]
    for item in raw.get('subentities', []):
        part = subentity(item)
        if part is not None:
            child = assembly(part['subentity_key'], definitions, model_reader, seen+(key,))
            append_component(result, child, part)
    scale = float(raw.get('model_scale_factor', 1))
    assert scale > 0
    result['vertices'] = [[v*scale for v in point] for point in result['vertices']]
    return result


def import_models(inventory_path, cache, core_definitions, dat_reader, output):
    """Verify archives/files, preserve notices, and return canonical-id-bound assemblies."""
    inventory_bytes = inventory_path.read_bytes()
    inventory = json.loads(inventory_bytes)
    result, source_hashes = {}, {}
    license_dir = output/'ModelLicenses'
    license_dir.mkdir(exist_ok=True)
    notices = []
    for package_id, package in inventory['packages'].items():
        selected = [r for r in inventory['records'] if r.get('package') == package_id and r['status'] == 'verified_source_mapping_pending_import']
        if not selected:
            continue
        archive_path = cache/(package_id+'.oxz')
        data = archive_path.read_bytes()
        assert hashlib.sha256(data).hexdigest() == package['archive_sha256'], archive_path
        with zipfile.ZipFile(archive_path) as archive:
            definitions, hashes = source_definitions(archive)
            definitions = core_definitions | definitions
            model_index = {Path(m['path']).name: m for m in package['model_inventory']}
            def model_reader(name):
                record = model_index.get(name)
                assert record is not None, (package_id, name)
                return dat_reader(Path(name), record['sha256'], data=archive.read(record['path']))
            license_name = package['license_declared'] or package['manifest_license_values'][0]
            license_id = 'CC-BY-NC-SA-4.0' if '4.0' in license_name else 'CC-BY-NC-SA-3.0'
            for record in selected:
                root = resolved(record['definition'], definitions)
                assert Path(root['model']).name == Path(record['model']['path']).name
                mesh = assembly(record['definition'], definitions, model_reader)
                mesh.update(id='xyzzy-showroom-'+record['id'], source=package_id+' / '+record['edition'],
                            license=license_id, sourceDefinition=record['definition'],
                            archiveSha256=package['archive_sha256'], sourceFiles=hashes,
                            modelFiles={m['path']:m['sha256'] for m in package['model_inventory']})
                points = mesh['vertices']
                dimensions = [max(p[i] for p in points)-min(p[i] for p in points) for i in range(3)]
                fields = resolved(record['definition'], definitions)
                result[record['id']] = dict(mesh=mesh, dimensions=dimensions, fields=fields,
                                           source=package_id+' / '+record['definition_name']+' (Oolite rendition)')
            names = [n for n in archive.namelist() if not n.endswith('/') and any(k in Path(n).name.lower() for k in ['licen','copying','readme','manifest'])]
            for index, name in enumerate(names):
                suffix = Path(name).suffix or '.txt'
                destination = package_id+'-'+str(index)+suffix
                (license_dir/destination).write_bytes(archive.read(name))
                notices.append(dict(package=package_id, sourcePath=name, bundledPath=destination,
                                    sha256=hashlib.sha256(archive.read(name)).hexdigest()))
        source_hashes[package_id] = package['archive_sha256']
    (license_dir/'index.json').write_text(json.dumps(notices,indent=2)+'\n')
    return result, {'inventory':hashlib.sha256(inventory_bytes).hexdigest(), 'archives':source_hashes}
