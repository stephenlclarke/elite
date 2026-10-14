"""Preserve source DAT appearance facts without claiming texture pixels are bundled."""
import copy
import math
import re


def dat_appearance(lines, corner_orders, source, license):
    """Read raw face triples and normalized UVs in the final geometry corner order."""
    start = lines.index('FACES') + 1
    colours = []
    for line in lines[start:start + len(corner_orders)]:
        rgb = [float(x) for x in re.split(r'[\s,]+', line)[:3]]
        assert len(rgb) == 3 and all(math.isfinite(x) for x in rgb), 'Invalid source face colour'
        colours.append(rgb)
    assert len(colours) == len(corner_orders), 'Truncated source faces'
    result = {'sourceFaceColours': colours}
    if 'TEXTURES' not in lines:
        return result
    start = lines.index('TEXTURES') + 1
    textures, mappings = [], []
    for index, order in enumerate(corner_orders):
        assert start + index < len(lines), 'Truncated source textures'
        parts = re.split(r'[\s,]+', lines[start + index])
        assert len(parts) == 3 + 2 * len(order), 'Invalid source texture corner count'
        name = parts[0]
        values = [float(x) for x in parts[1:]]
        assert all(math.isfinite(x) for x in values), 'Nonfinite source texture coordinates'
        sx, sy = values[:2]
        assert sx > 0 and sy > 0, 'Invalid source texture scale'
        uv = [[values[2 + 2*i] / sx, values[3 + 2*i] / sy] for i in order]
        assert all(math.isfinite(x) for pair in uv for x in pair), 'Nonfinite normalized UV'
        texture = {'name': name, 'source': source, 'license': license}
        if texture not in textures:
            textures.append(texture)
        mappings.append({'texture': textures.index(texture), 'uv': uv})
    result.update(sourceTextures=textures, sourceFaceTextures=mappings)
    return result


def append_appearance(parent, child, parent_face_count, child_face_count):
    """Remap component-local references, retaining face alignment in mixed assemblies."""
    for palette_key, assignments_key, empty in [
        ('materials', 'faceMaterials', -1),
        ('sourceTextures', 'sourceFaceTextures', {'texture': -1, 'uv': []}),
    ]:
        if not any(key in mesh for key in (palette_key, assignments_key) for mesh in (parent, child)):
            continue
        palette = parent.setdefault(palette_key, [])
        remap = []
        for item in child.get(palette_key, []):
            if item not in palette:
                palette.append(copy.deepcopy(item))
            remap.append(palette.index(item))
        assignments = parent.setdefault(assignments_key, [copy.deepcopy(empty) for _ in range(parent_face_count)])
        assert len(assignments) == parent_face_count, 'Invalid parent appearance face count'
        incoming = child.get(assignments_key, [copy.deepcopy(empty) for _ in range(child_face_count)])
        assert len(incoming) == child_face_count, 'Invalid child appearance face count'
        for item in incoming:
            if palette_key == 'materials':
                assert item == -1 or 0 <= item < len(remap), 'Invalid material reference'
                assignments.append(-1 if item == -1 else remap[item])
            else:
                index = item['texture']
                assert index == -1 or 0 <= index < len(remap), 'Invalid texture reference'
                assert index != -1 or item['uv'] == [], 'Untextured face has UVs'
                assignments.append({'texture': -1 if index == -1 else remap[index], 'uv': copy.deepcopy(item['uv'])})
    if 'sourceFaceColours' in parent or 'sourceFaceColours' in child:
        # Missing raw source colour has no invented RGB value; omit this optional
        # field for mixed assemblies rather than manufacture archival facts.
        if 'sourceFaceColours' not in parent or 'sourceFaceColours' not in child:
            parent.pop('sourceFaceColours', None)
        else:
            assert len(parent['sourceFaceColours']) == parent_face_count
            assert len(child['sourceFaceColours']) == child_face_count
            parent['sourceFaceColours'].extend(copy.deepcopy(child['sourceFaceColours']))
