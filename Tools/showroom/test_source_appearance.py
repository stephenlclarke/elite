"""Regression coverage for source appearance and component reference preservation."""
import hashlib
import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch


def module(name, filename):
    spec = importlib.util.spec_from_file_location(name, Path(__file__).with_name(filename))
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


catalogue = module('catalogue', 'build-catalogue.py')
appearance = module('appearance', 'source-appearance.py')
expansion = module('expansion', 'expansion-models.py')


def dat(normal='0,0,1', texture='hull.png 2 4 0 0 2 0 0 4'):
    text = 'NVERTS 3\nNFACES 1\nVERTEX\n0,0,0\n1,0,0\n0,1,0\nFACES\n1,0,0,' + normal + ',3,0,1,2\n'
    if texture is not None:
        text += 'TEXTURES\n' + texture + '\nEND\n'
    data = text.encode()
    return catalogue.dat_mesh(Path('test.dat'), hashlib.sha256(data).hexdigest(), data)


class SourceAppearanceTests(unittest.TestCase):
    def test_numeric_names_resolution_preserves_archival_tokens_and_uvs(self):
        mesh = dat(texture='0 2 4 0 0 2 0 0 4')
        before = repr(mesh)
        self.assertEqual(appearance.resolved_texture_names(
            ['NAMES 2', 'comray.png', 'commies_details.png', '', 'NORMALS'],
            ['0', '1', 'hull.png']), ['comray.png', 'commies_details.png', 'hull.png'])
        self.assertEqual(repr(mesh), before)
        self.assertEqual(mesh['sourceTextures'][0]['name'], '0')
        self.assertEqual(mesh['sourceFaceTextures'][0]['uv'], [[0, 1], [1, 0], [0, 0]])
        self.assertEqual(appearance.resolved_texture_names([], ['hull.png']), ['hull.png'])

    def test_invalid_names_counts_and_indices_fail_closed(self):
        cases = [([], ['0']), (['NAMES 1', 'hull.png', 'END'], ['1']),
                 (['NAMES 1', 'hull.png', 'END'], ['-1']),
                 (['NAMES 2', 'hull.png', 'END'], ['0']),
                 (['NAMES 1', 'hull.png', 'extra.png', 'END'], ['0']),
                 (['NAMES -1', 'END'], ['0']), (['NAMES 4097'], ['0']),
                 (['NAMES 1', 'hull.png', 'NAMES 1', 'other.png'], ['0'])]
        for lines, tokens in cases:
            with self.subTest(lines=lines, tokens=tokens), self.assertRaises(AssertionError):
                appearance.resolved_texture_names(lines, tokens)

    def test_selected_commies_diffuse_overrides_and_inheritance(self):
        # Config/shipdata.plist from Commies 2.20: actual selected player chains.
        definitions = {
            'comviper': {'materials': {'comray.png': {'diffuse_map': 'comray.png'}}},
            'sunray': {'like_ship': 'comviper', 'materials': {
                'comray.png': {'diffuse_map': 'comray_sun.png'},
                'commies_details.png': {'diffuse_map': 'commies_details.png'}}},
            'sunray-player': {'like_ship': 'sunray'},
            'commilray': {'materials': {'comrayii.png': {'diffuse_map': 'comrayii.png'}}},
            'commilray-player': {'like_ship': 'commilray'}}
        before = repr(definitions)
        self.assertEqual(appearance.resolved_diffuse_map(definitions, 'sunray-player', 'comray.png'), 'comray_sun.png')
        self.assertEqual(appearance.resolved_diffuse_map(definitions, 'sunray-player', 'commies_details.png'), 'commies_details.png')
        self.assertEqual(appearance.resolved_diffuse_map(definitions, 'commilray-player', 'comrayii.png'), 'comrayii.png')
        self.assertEqual(repr(definitions), before)

    def test_child_material_map_replaces_parent_and_dictionary_diffuse_is_supported(self):
        definitions = {'base': {'materials': {'parent.png': {'diffuse_map': 'overridden.png'}}},
                       'child': {'like_ship': 'base', 'materials': {
                           'child.png': {'diffuse_map': {'name': 'resolved.png', 'repeat_s': True}}}}}
        self.assertEqual(appearance.resolved_diffuse_map(definitions, 'child', 'parent.png'), 'parent.png')
        self.assertEqual(appearance.resolved_diffuse_map(definitions, 'child', 'child.png'), 'resolved.png')

    def test_invalid_inheritance_and_diffuse_values_fail_closed(self):
        cases = [({'a': {'like_ship': 'a'}}, 'a'),
                 ({'a': {'like_ship': 'b'}, 'b': {'like_ship': 'a'}}, 'a'),
                 ({'a': {'like_ship': 'missing'}}, 'a'),
                 ({'a': {'like_ship': 1}}, 'a'),
                 ({'a': {'materials': []}}, 'a'),
                 ({'a': {'materials': {'hull.png': {'diffuse_map': {}}}}}, 'a'),
                 ({'a': {'materials': {'hull.png': {'diffuse_map': ''}}}}, 'a')]
        chain = {str(i): {'like_ship': str(i + 1)} for i in range(128)}
        chain['128'] = {}
        cases.append((chain, '0'))
        for definitions, key in cases:
            with self.subTest(definitions=definitions), self.assertRaises(AssertionError):
                appearance.resolved_diffuse_map(definitions, key, 'hull.png')

    def test_z_reflection_reverses_uv_with_face_and_preserves_placeholder_rgb(self):
        mesh = dat()
        self.assertEqual(mesh['faces'], [[2, 1, 0]])
        self.assertEqual(mesh['sourceFaceTextures'], [{'texture': 0, 'uv': [[0, 1], [1, 0], [0, 0]]}])
        self.assertEqual(mesh['sourceFaceColours'], [[1, 0, 0]])
        self.assertNotIn('materials', mesh)
        self.assertIn(mesh['sha256'], mesh['sourceTextures'][0]['source'])
        self.assertIn('not established', mesh['sourceTextures'][0]['license'])

    def test_normal_correction_and_reflection_cancel_corner_reversal(self):
        mesh = dat(normal='0,0,-1')
        self.assertEqual(mesh['faces'], [[0, 1, 2]])
        self.assertEqual(mesh['sourceFaceTextures'][0]['uv'], [[0, 0], [1, 0], [0, 1]])

    def test_untextured_source_has_no_invented_texture(self):
        mesh = dat(texture=None)
        self.assertNotIn('sourceTextures', mesh)
        self.assertEqual(mesh['sourceFaceColours'], [[1, 0, 0]])

    def test_invalid_uv_records_fail_closed(self):
        for texture in ['hull.png 0 1 0 0 1 0 0 1', 'hull.png 1 1 0 0',
                        'hull.png 1 1 nan 0 1 0 0 1', 'END']:
            with self.subTest(texture=texture), self.assertRaises((AssertionError, ValueError)):
                dat(texture=texture)

    def test_mixed_component_assembly_remaps_texture_and_material_indices(self):
        parent = dat(texture=None)
        child = dat()
        parent['components'], child['components'] = ['hull'], ['engine']
        parent['materials'] = [{'name': 'hull', 'colour': 0xffffffff, 'emissive': False}]
        parent['faceMaterials'] = [0]
        child['materials'] = [{'name': 'engine', 'colour': 0x00ff00ff, 'emissive': True}]
        child['faceMaterials'] = [0]
        expansion.append_component(parent, child, {})
        self.assertEqual(parent['faceMaterials'], [0, 1])
        self.assertEqual(parent['sourceFaceTextures'][0], {'texture': -1, 'uv': []})
        self.assertEqual(parent['sourceFaceTextures'][1]['texture'], 0)
        self.assertEqual(len(parent['sourceFaceColours']), 2)
        expansion.append_component(parent, child, {})
        self.assertEqual(parent['faceMaterials'], [0, 1, 1])
        self.assertEqual(len(parent['materials']), 2)
        self.assertEqual(len(parent['sourceTextures']), 1)

    def test_core_composite_preserves_uvs_and_deduplicates(self):
        definitions = [dict(definition_id='root', resolved_core_fields={'model': 'test.dat', 'subentities': [{'subentity_key': 'child'}]}),
                       dict(definition_id='child', resolved_core_fields={'model': 'test.dat'})]
        fixtures = [dat(), dat()]
        with patch.object(catalogue, 'dat_mesh', side_effect=fixtures):
            mesh = catalogue.composite_mesh(definitions[0], definitions, {'test.dat': {'sha256': 'unused'}}, Path('.'))
        self.assertEqual(len(mesh['sourceTextures']), 1)
        self.assertEqual([m['texture'] for m in mesh['sourceFaceTextures']], [0, 0])
        self.assertEqual(mesh['faces'], [[2, 1, 0], [5, 4, 3]])

    def test_invalid_component_references_are_rejected(self):
        parent, child = dat(), dat()
        child['sourceFaceTextures'][0]['texture'] = 2
        with self.assertRaises(AssertionError):
            appearance.append_appearance(parent, child, 1, 1)


if __name__ == '__main__':
    unittest.main()
