#!/usr/bin/env python3
"""Stage research imports for review; runtime ships live in individual TOMLs."""
import argparse
import hashlib
import json
import importlib.util
import re
from pathlib import Path

appearance_spec = importlib.util.spec_from_file_location('source_appearance', Path(__file__).with_name('source-appearance.py'))
appearance = importlib.util.module_from_spec(appearance_spec)
appearance_spec.loader.exec_module(appearance)

LABELS = {
    'required_crew_including_commander': ('Required crew', 'people'),
    'reserved_crew_accommodation': ('Reserved crew quarters', 'people'),
    'cargo_tonnes': ('Cargo', 't'), 'maximum_speed_project_units': ('Speed', 'project units/s'),
    'hull_energy': ('Hull energy', 'project units'),
    'energy_recharge_per_second': ('Energy recharge', 'project units/s'),
    'roll_radians_per_second': ('Roll', 'rad/s'), 'pitch_radians_per_second': ('Pitch', 'rad/s'),
    'yaw_radians_per_second': ('Yaw', 'rad/s'),
    'acceleration_project_units_per_second_squared': ('Acceleration', 'project units/s2'),
    'fore_shield_max': ('Front shield', 'project units'), 'aft_shield_max': ('Rear shield', 'project units'),
    'fore_shield_recharge_per_second': ('Front recharge', 'project units/s'),
    'aft_shield_recharge_per_second': ('Rear recharge', 'project units/s'),
    'hyperspace_range_ly': ('Jump range', 'LY'), 'jump_spool_seconds': ('Jump spool', 's'),
    'fuel_capacity_tenths_ly': ('Fuel capacity', '0.1 LY'), 'laser_facing_mask': ('Laser facings', 'bit mask'),
    'forward_laser': ('Forward laser', ''), 'missile_capacity': ('Missile capacity', 'pylons'),
    'new_refit_initial_missiles': ('Initial missiles', 'missiles'),
    'equipment_capacity_units': ('Equipment capacity', 'project slots'),
    'docking_computer': ('Docking computer', ''), 'hyperspace_drive': ('Hyperspace drive', ''),
    'cargo_expansion_tonnes': ('Cargo expansion', 't'),
}
OOLITE_FIELDS = {
    'max_cargo': ('Cargo', 't'), 'max_flight_speed': ('Speed', 'Oolite units/s'),
    'max_energy': ('Hull energy', 'Oolite units'), 'energy_recharge_rate': ('Energy recharge', 'Oolite units/s'),
    'max_flight_roll': ('Roll', 'rad/s'), 'max_flight_pitch': ('Pitch', 'rad/s'),
    'max_flight_yaw': ('Yaw', 'rad/s'), 'thrust': ('Thrust', 'Oolite raw'),
    'weapon_facings': ('Laser facings', 'bit mask'), 'missiles': ('Initial missiles', 'missiles'),
    'max_missiles': ('Missile capacity', 'pylons'), 'forward_weapon_type': ('Forward laser', ''),
    'aft_weapon_type': ('Rear laser', ''), 'has_ecm': ('ECM capability', 'source predicate'),
    'has_scoop': ('Fuel scoops', 'source predicate'), 'has_hyperspace_motor': ('Hyperdrive', 'source predicate'),
}


def normal(name):
    """Compare documented names, retaining distinct marks and ship classes."""
    name = name.lower().replace('mk iii', 'mk3').replace('mk ii', 'mk2').replace('mk i', 'mk1')
    return re.sub(r'[^a-z0-9]', '', name)


def field(key, value, label, unit='', status='source', basis=''):
    """Keep unknown, numeric zero and version-specific units distinct."""
    number = None
    if isinstance(value, (float, int)) and not isinstance(value, bool):
        number = value
    elif isinstance(value, str):
        try:
            number = float(value)
        except ValueError:
            pass
    text = 'Unavailable' if value is None else str(value)
    if isinstance(value, bool):
        text = 'Yes' if value else 'No'
    if isinstance(value, list):
        text = ', '.join(map(str, value)) or 'None defined'
    if isinstance(value, str) and (value.startswith('EQ_') or value.startswith('WEAPON_')):
        text = value.removeprefix('EQ_').removeprefix('WEAPON_').replace('_',' ').title()
    if unit and value is not None:
        text += ' ' + unit
    return dict(key=key, label=label, text=text, number=number, unit=unit, status=status, basis=basis)


def oolite_field(key, raw, label, unit, identity):
    """Prefer explicit source facts, then verified source-engine defaults."""
    actual_key = 'hyperspace_motor' if key == 'has_hyperspace_motor' else key
    value = raw.get(actual_key)
    status = 'source'
    basis = 'O08 '+identity
    defaults = {'max_flight_yaw':raw.get('max_flight_pitch',1),
                'aft_weapon_type':'EQ_WEAPON_NONE', 'has_hyperspace_motor':True,
                'max_missiles':min(32,int(float(raw.get('missiles',0)))), 'has_scoop':False,
                'max_cargo':0, 'weapon_facings':15, 'has_ecm':False, 'max_energy':200,
                'energy_recharge_rate':1, 'max_flight_speed':160, 'max_flight_roll':2,
                'max_flight_pitch':1, 'thrust':15, 'forward_weapon_type':'EQ_WEAPON_NONE', 'missiles':0}
    if str(raw.get('is_station','no')).lower() in {'yes','true','1'}:
        defaults['max_flight_speed'] = 0
    if value is None and key in defaults:
        value = defaults[key]
        status = 'source engine default'
        basis += '; pinned ShipEntity.m initialization/default; before fitted/random equipment effects'
    if key == 'has_hyperspace_motor':
        value = str(value).lower() not in {'false','no','0'} and float(raw.get('hyperspace_motor_spin_time',15)) >= 0
        basis += '; hyperspace_motor and nonnegative spin time, not an invented has_hyperspace_motor key'
    return field(key,value,label,unit,status=status,basis=basis)


def estimated_dimensions(geometry, models):
    """Expose low-confidence envelope estimates without substituting preview geometry."""
    reference = geometry.get('reference_model','').removeprefix('O08 ')
    if reference not in models:
        return None
    scale = geometry.get('linear_scale',geometry.get('volume_ratio',geometry.get('volume_scale',1))**(1/3))
    return [float(f'{v*scale:.2g}') for v in models[reference]['geometry_envelope']['dimensions_xyz']]


def dat_mesh(path, expected_hash, data=None):
    """Read source vertices/faces and retain outward winding using supplied normals."""
    data = path.read_bytes() if data is None else data
    assert hashlib.sha256(data).hexdigest() == expected_hash, path
    clean = re.sub(r'//[^\n]*|#[^\n]*', '', data.decode('utf-8-sig'))
    lines = [line.strip() for line in clean.splitlines() if line.strip()]
    nverts = int(next(line.split()[1] for line in lines if line.startswith('NVERTS')))
    nfaces = int(next(line.split()[1] for line in lines if line.startswith('NFACES')))
    start = lines.index('VERTEX') + 1
    vertices = [[float(x) for x in re.split(r'[\s,]+', line)[:3]] for line in lines[start:start+nverts]]
    assert len(vertices) == nverts
    normals = []
    if 'NORMALS' in lines:
        start = lines.index('NORMALS') + 1
        normals = [[float(x) for x in re.split(r'[\s,]+', line)[:3]] for line in lines[start:start+nverts]]
    start = lines.index('FACES') + 1
    faces, corner_orders = [], []
    for line in lines[start:start+nfaces]:
        parts = re.split(r'[\s,]+', line)
        count = int(parts[6])
        face = [int(x) for x in parts[7:7+count]]
        assert len(face) >= 3 and all(0 <= x < nverts for x in face)
        order = list(range(len(face)))
        a, b, c = [vertices[i] for i in face[:3]]
        ab, ac = [b[i]-a[i] for i in range(3)], [c[i]-a[i] for i in range(3)]
        cross = [ab[1]*ac[2]-ab[2]*ac[1], ab[2]*ac[0]-ab[0]*ac[2], ab[0]*ac[1]-ab[1]*ac[0]]
        normal_vector = [float(x) for x in parts[3:6]]
        if not any(normal_vector) and normals:
            normal_vector = [sum(normals[v][i] for v in face) for i in range(3)]
        if sum(cross[i]*normal_vector[i] for i in range(3)) < 0:
            face.reverse()
            order.reverse()
        # Reflect Z into the native camera convention, also reversing winding.
        faces.append(list(reversed(face)))
        corner_orders.append(list(reversed(order)))
    vertices = [[v[0], v[1], -v[2]] for v in vertices]
    return dict(id=path.name, vertices=vertices, faces=faces, sha256=expected_hash,
                source='Oolite 574ca848', license='CC-BY-NC-SA-3.0',
                **appearance.dat_appearance(
                    lines, corner_orders, f'{path.name}; sha256={expected_hash}',
                    'Texture licence not established from DAT; reference only, no pixels bundled'))


def composite_mesh(root, definitions, models, directory, seen=None):
    """Assemble source hull/dock subentities; omit non-geometry flashers."""
    seen = set() if seen is None else seen
    assert root['definition_id'] not in seen, 'Cyclic subentity graph'
    seen = seen | {root['definition_id']}
    raw = root['resolved_core_fields']
    name = raw['model']
    result = dat_mesh(directory/name, models[name]['sha256'])
    parts = raw.get('subentities', [])
    for part in parts:
        if not isinstance(part, dict) or part.get('type') == 'flasher':
            continue
        child = next((d for d in definitions if d['definition_id'] == part.get('subentity_key')), None)
        if child is None or child['resolved_core_fields'].get('model') not in models:
            continue
        mesh = composite_mesh(child, definitions, models, directory, seen)
        orientation = part.get('orientation', [1, 0, 0, 0])
        q = [float(v) for v in (orientation.split() if isinstance(orientation, str) else orientation)]
        norm = sum(v*v for v in q)**0.5
        assert norm > 0
        w, x, y, z = [v/norm for v in q]
        position = part.get('position', [0, 0, 0])
        pos = [float(v) for v in (position.split() if isinstance(position, str) else position)]
        offset = len(result['vertices'])
        for vx, vy, vz in mesh['vertices']:
            vz = -vz
            rx = (1-2*y*y-2*z*z)*vx + (2*x*y-2*z*w)*vy + (2*x*z+2*y*w)*vz
            ry = (2*x*y+2*z*w)*vx + (1-2*x*x-2*z*z)*vy + (2*y*z-2*x*w)*vz
            rz = (2*x*z-2*y*w)*vx + (2*y*z+2*x*w)*vy + (1-2*x*x-2*y*y)*vz
            result['vertices'].append([rx+pos[0], ry+pos[1], -(rz+pos[2])])
        appearance.append_appearance(result, mesh, len(result['faces']), len(mesh['faces']))
        result['faces'].extend([[v+offset for v in face] for face in mesh['faces']])
    result['id'] = 'O08-'+root['definition_id']
    return result


def main():
    """Generate the full identity/refit catalogue and only verified corresponding models."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--research', type=Path, default=Path('docs/research'))
    parser.add_argument('--expansions', type=Path, help='Recovered P30/P46 package directories for verified source geometry')
    parser.add_argument('--models', type=Path, required=True, help='Pinned O08 Resources/Models directory')
    parser.add_argument('--model-inventory',type=Path,default=Path('docs/SHIP-MODEL-RESEARCH.json'))
    parser.add_argument('--additional-inventory',type=Path,default=Path('docs/SHIP-MODEL-RESEARCH-2.json'))
    parser.add_argument('--model-cache',type=Path,help='Verified archive cache containing Pxx/S9/Santa/IC.oxz')
    args = parser.parse_args()
    research = args.research
    input_names = ['ships.md','data/player-ship-adaptation.json','data/oolite-ship-specifications.json',
                   'data/gba-ship-specifications.json','data/elite-dangerous-outfitting.json','data/ship-crew-profiles.json']
    inputs = {name:(research/name).read_bytes() for name in input_names}
    adaptation = json.loads(inputs['data/player-ship-adaptation.json'])
    oolite = json.loads(inputs['data/oolite-ship-specifications.json'])
    gba = json.loads(inputs['data/gba-ship-specifications.json'])
    ed = json.loads(inputs['data/elite-dangerous-outfitting.json'])
    crew = json.loads(inputs['data/ship-crew-profiles.json'])
    for name, expected in {
        'src/Core/Entities/ShipEntity.m':'78f26fc31c4bccf935bc730542cbb2fc03c442f7057fc6592e93c7005751d623',
        'src/Core/OOTypes.h':'586e295734a0c6b56542920efe3a66dd203bd302af65ea8c03f9f26c8755580f'}.items():
        data = (args.models.parent.parent/name).read_bytes()
        assert hashlib.sha256(data).hexdigest() == expected, 'Unpinned source-engine defaults'
        inputs['engine/'+name] = data
    profiles = {p['canonical_ship_id']: p for p in adaptation['complete_project_profiles']}
    definitions = oolite['definitions']
    models = {m['model']: m for m in oolite['models']}
    extra_models, extra_provenance = {}, {}
    if args.model_cache:
        module_spec = importlib.util.spec_from_file_location('expansion_models',Path(__file__).with_name('expansion-models.py'))
        importer = importlib.util.module_from_spec(module_spec)
        module_spec.loader.exec_module(importer)
        core_raw = {d['definition_id']:d['resolved_core_fields'] for d in definitions}
        extra_models, extra_provenance = importer.import_models(args.model_inventory,args.model_cache,core_raw,dat_mesh,Path('Sources/EliteCore/Resources'))
        if args.additional_inventory.exists():
            additional, additional_provenance = importer.import_additional_models(args.additional_inventory,args.model_cache,core_raw,dat_mesh,Path('Sources/EliteCore/Resources'))
            assert not (extra_models.keys() & additional.keys()), 'Duplicate new canonical model mappings'
            extra_models.update(additional)
            extra_provenance['additional'] = additional_provenance
    records = []
    used_models = {}
    for line in inputs['ships.md'].decode().splitlines():
        if not re.match(r'^\| SH\d{3} \|', line):
            continue
        identity, name, kind, appearances, evidence = [x.strip() for x in line.split('|')[1:6]]
        profile = profiles.get(identity)
        variants = []
        crew_row = next((r for r in crew['rows'] if r['canonical_ship_id'] == identity), {})
        if profile:
            fields = [field(key, data['value'], *LABELS.get(key, (key, '')),
                            status=data['status'], basis=data['basis']) for key, data in profile['fields'].items()]
            for key, label, value, unit in [
                ('fitted_passenger_berths', 'Fitted passenger berths', 0, 'berths'),
                ('passengers_aboard', 'Passengers aboard', 0, 'people'),
                ('free_passenger_places', 'Free passenger places', 0, 'people'),
                ('hold_used_by_cabins', 'Hold used by cabins', 0, 't'),
                ('usable_cargo_after_fit', 'Usable cargo after fit', profile['fields']['cargo_tonnes']['value'], 't')]:
                fields.append(field(key, value, label, unit, status='standard unladen refit',
                                    basis='Zero fitted charter berths; operating quarters are outside usable cargo. Berths require 5t plus one equipment unit each.'))
            facings = int(profile['fields']['laser_facing_mask']['value'])
            for mount, bit in [('rear',2),('left',4),('right',8)]:
                fields.append(field(mount+'_laser','Empty (standard refit)' if facings & bit else 'Unsupported mount',
                                    mount.title()+' laser',status='estimated project fitting',
                                    basis='Facing mask is authoritative; no secondary laser is specified in this standard refit. Empty is a labelled starting-fit estimate, not extra equipment.'))
            variants.append(dict(id=profile['profile_id'], title='Common project refit', group='project-refit-v1',
                                 context='Adaptation; borrowed and estimated fields, not historical native specifications.',
                                 fields=fields))
        aliases = {'Dodo station':'Dodecahedron Station', 'Thargon':'Thargoid Robot Fighter'}
        source_name = aliases.get(name, name)
        matches = [d for d in definitions if normal(d['resolved_core_fields'].get('name', '')) == normal(source_name)]
        model = profile.get('geometry', {}).get('model') if profile else None
        for definition in matches:
            raw = definition['resolved_core_fields']
            player = definition['is_shipyard_entry']
            fields = [oolite_field(key, raw, label, unit, definition['definition_id'])
                      for key, (label, unit) in OOLITE_FIELDS.items()]
            if player:
                yard = definition['shipyard']
                fields += [field('price', yard.get('price'), 'Price', 'CR'),
                           field('technology', yard.get('techlevel'), 'Tech index'),
                           field('equipment', yard.get('optional_equipment'), 'Offered equipment')]
            variants.append(dict(id='O08-'+definition['definition_id'],
                                 title='Oolite '+('player ' if player else 'NPC ')+definition['definition_id'],
                                 group='oolite-'+('player' if player else 'npc'),
                                 context='O08 574ca848; base dictionary before fitted/random equipment effects; engine units. Capability predicates are not installed guarantees.',
                                 fields=fields))
            if model is None and raw.get('model') in models:
                model = raw['model']
        for projection in adaptation['gba_projection_profiles']:
            if projection['canonical_ship_id'] != identity:
                continue
            for resource_id in projection['source_resource_ids']:
                source = next(x for x in gba['objects'] if x['source_type_id'] == resource_id)
                fields = [field(key, source.get(key), label, unit, basis='S37 source object '+str(resource_id))
                          for key, label, unit in [('energy','Hull energy','GBA raw'),
                              ('maximum_velocity_raw','Speed','GBA raw'),('missiles_default','Initial missiles','missiles'),
                              ('npc_laser_strength','NPC laser strength','GBA raw'),
                              ('player_cargo_capacity_tonnes','Player cargo','t')]]
                if profile:
                    for index, value in enumerate(fields):
                        if value['key'] == 'player_cargo_capacity_tonnes' and value['number'] is None:
                            fields[index] = field(value['key'], profile['fields']['cargo_tonnes']['value'],
                                'Estimated player cargo', 't', status='estimated - low confidence',
                                basis='Same canonical hull common project refit; no GBA-native player hold established. Not NPC dropped cargo or a historical measurement.')
                variants.append(dict(id='S37-'+str(resource_id), title='GBA NPC '+source['name'], group='gba-npc',
                                     context='S37 2107c8af; source raw NPC fields, not inferred player capabilities.', fields=fields))
        for source in ed['ships']:
            if source['canonical_ship_id'] != identity:
                continue
            props = source['properties']
            fields = [field(key, props.get(key), label, unit, basis='D23 '+source['dataset_ship_key'])
                      for key, label, unit in [('speed','Base speed','m/s'),('boost','Boost','m/s'),
                          ('pitch','Pitch','deg/s'),('roll','Roll','deg/s'),('yaw','Yaw','deg/s'),
                          ('hullMass','Hull mass','t'),('baseShieldStrength','Shield input','ED raw'),
                          ('baseArmour','Armour input','ED raw'),('hullCost','Hull price','CR')]]
            fields += [field('retail_cost', source['retail_cost'], 'Retail loadout', 'CR'),
                       field('hardpoints', source['slots']['hardpoints'], 'Hardpoint sizes'),
                       field('internal', source['slots']['internal'], 'Internal slots')]
            variants.append(dict(id='D23-'+source['dataset_ship_key'], title='ED Coriolis '+source['source_name'],
                                 group='ed-coriolis', context='D23 '+ed['commit'][:8]+': community outfitting snapshot; equipped FSD/shield results not inferred.',
                                 fields=fields))
        crew_row = next((r for r in crew['rows'] if r['canonical_ship_id'] == identity), {})
        for index, source in enumerate(crew_row.get('native_edition_records', [])):
            seats = 'seats' in source['kind']
            fields = [field('crew_minimum', source.get('minimum'), 'Flight seats' if seats else 'Documented minimum', 'people'),
                      field('crew_maximum', source.get('maximum'), 'Maximum flight seats' if seats else 'Documented maximum', 'people')]
            if 'capacity' in source['kind'] or 'accommodation' in source['kind']:
                label = 'Documented passenger capacity' if 'passenger' in source['kind'] else 'Life support accommodation'
                value = source.get('maximum') if source.get('maximum') is not None else source.get('minimum')
                fields = [field('documented_capacity',value,label,'people',basis=source['kind']+'; not minimum operating crew or fitted player berths')]
            elif source.get('maximum') is None and source.get('minimum') is not None:
                fields[1] = field('crew_maximum',source['minimum'],'Estimated complement','people',
                                  status='estimated - medium confidence',
                                  basis='Same source single-pilot narrative; no separate maximum stated.')
            if 'extra_hired_crew' in source:
                fields.append(field('extra_hired_crew', source['extra_hired_crew'], 'Additional hired crew', 'people'))
            variants.append(dict(id='CREW-'+identity+'-'+str(index), title=source['version']+' crew',
                                 group='crew-'+source['version']+'-'+normal(source['kind']), context=source.get('kind','')+'; '+source.get('source_id','')+'; crew is separate from passenger cabins.', fields=fields))
        if not variants and kind == 'Station':
            station_values = [float(d['resolved_core_fields'].get('max_energy',200)) for d in definitions
                              if d['definition_id'] in {'coriolis-station','dodecahedron-station'}]
            energy_estimate = float(f'{sum(station_values)/len(station_values):.2g}')
            variants.append(dict(id='ESTIMATED-'+identity,title='Estimated station comparison',group='estimated-station',
                context='Low-confidence station-role estimate from the pinned Oolite Coriolis/Dodo class; not measured original Wheel specifications or player hardware.',
                fields=[field('max_energy',energy_estimate,'Hull energy','Oolite units',status='estimated - low confidence',basis='Mean same-role Coriolis/Dodo base energy, rounded to two significant figures'),
                        field('max_flight_speed',0,'Orbital translation','Oolite units/s',status='estimated - low confidence',basis='Station-role baseline assumes fixed orbital centre; rotation is separate')]))
        geometry = profile.get('geometry', {}) if profile else {}
        dimensions = geometry.get('dimensions_xyz') or estimated_dimensions(geometry,models)
        geometry_context = ('Estimated dimensions, low confidence: '+geometry.get('reference_model','')+'; '+geometry.get('method','')+'; no authentic mesh substitution.') if dimensions and 'estimated' in geometry.get('status','').lower() and 'source envelope' not in geometry.get('status','') else 'Source model units; envelope, not internal volume or SI dimensions.'
        if model in models:
            definition = next((d for d in matches if d['resolved_core_fields'].get('model') == model), None)
            model_id = 'O08-'+definition['definition_id'] if definition else model
            used_models[model_id] = definition if definition else model
            dimensions = models[model]['geometry_envelope']['dimensions_xyz']
            model = model_id
        elif args.expansions and (geometry.get('source_id'), geometry.get('model')) in {
                ('P46', 'vector.dat'), ('P46', 'vector_inspection.dat'), ('P30', 'rrsfl_arafura.dat')}:
            source_id, file_name = geometry['source_id'], geometry['model']
            model = source_id+'-'+file_name
            source = 'Vector 1.7.2 / Svengali' if source_id == 'P46' else 'Rescue Stations 1.5.4 / cim, spara'
            used_models[model] = {'external_path': args.expansions/source_id/'Models'/file_name,
                                  'sha256': geometry['model_sha256'], 'source': source}
        else:
            model = None
        model_source = used_models[model].get('source', 'Oolite 574ca848') if model and isinstance(used_models[model], dict) else ('Oolite 574ca848' if model else None)
        if identity in extra_models:
            extra = extra_models[identity]
            model = extra['mesh']['id']
            model_source = extra['source']
            dimensions = extra['dimensions']
            fields = [oolite_field(key,extra['fields'],label,unit,model) for key,(label,unit) in OOLITE_FIELDS.items()]
            variants.append(dict(id=model,title='Oolite source assembly',group='oolite-expansion',
                context='Exact selected source definition and assembled model; pre-equipment NPC fields, not a player-hull grant or ED geometry.',fields=fields))

        records.append(dict(id=identity, name=name, shipClass=kind, appearances=appearances, evidence=re.sub(r'\[([^\]]+)\]\([^)]+\)', r'\1', evidence),
                            refit=profile is not None, model=model, modelSource=model_source, dimensions=dimensions,
                            geometryContext='Source model units; envelope, not internal volume or SI dimensions.' if model else (geometry_context if dimensions else 'No inspected corresponding mesh or defensible dimensional estimate.'),
                            profiles=variants))
    assert len(records) == len(adaptation['catalogue_scope'])
    assert sum(r['refit'] for r in records) == len(profiles)
    assert len({r['id'] for r in records}) == len(records)
    meshes = []
    for model_id, definition in sorted(used_models.items()):
        if isinstance(definition, dict) and 'external_path' in definition:
            mesh = dat_mesh(definition['external_path'], definition['sha256'])
            mesh['id'] = model_id
            mesh['source'] = definition['source']
        elif isinstance(definition, dict):
            mesh = composite_mesh(definition, definitions, models, args.models)
        else:
            mesh = dat_mesh(args.models/definition, models[definition]['sha256'])
        meshes.append(mesh)
    meshes += [m['mesh'] for m in extra_models.values()]
    output = Path('reports/showroom-import')
    output.mkdir(parents=True,exist_ok=True)
    manifest = dict(revision='2026-10-13-catalogue-v2', records=records, extraModels=extra_provenance,
                    inputs={name:hashlib.sha256(data).hexdigest() for name,data in inputs.items()})
    (output/'ShipCatalogue.json').write_text(json.dumps(manifest, ensure_ascii=True, separators=(',', ':'))+'\n')
    (output/'ShowroomModels.json').write_text(json.dumps(meshes, ensure_ascii=True, separators=(',', ':'))+'\n')
    print('Catalogue:',len(records),'Refits:',sum(r['refit'] for r in records),'Source meshes:',len(meshes),
          'Modelled records:',sum(r['model'] is not None for r in records))
    for r in records:
        if r['model']:print(r['id'],r['name'],r['model'])


if __name__ == '__main__':
    main()
