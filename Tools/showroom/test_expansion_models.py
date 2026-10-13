"""Source assembly regression checks independent of any downloaded game engine."""
import importlib.util
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location('expansion_models',Path(__file__).with_name('expansion-models.py'))
assembly = importlib.util.module_from_spec(spec)
spec.loader.exec_module(assembly)


def triangle(name):
    return dict(vertices=[[1,0,0],[0,1,0],[0,0,-1]],faces=[[2,1,0]],id=name)


class SourceAssemblyTests(unittest.TestCase):
    def test_legacy_subentity_and_flasher_have_distinct_geometry_semantics(self):
        self.assertIsNone(assembly.subentity('*FLASHER* 1 2 3 120 1 .5 12'))
        self.assertEqual(assembly.subentity('wing 10 20 30 1 0 0 0')['position'],['10','20','30'])

    def test_inherited_hull_and_separate_engine_transform_are_preserved(self):
        definitions = {'base':{'model':'hull.dat'},'ship':{'like_ship':'base',
          'subentities':['engine 10 20 30 0 0 1 0']},'engine':{'model':'engine.dat'}}
        mesh = assembly.assembly('ship',definitions,triangle)
        self.assertEqual(mesh['components'],['ship','engine'])
        self.assertEqual(mesh['vertices'][3:],[ [9,20,-30],[10,21,-30],[10,20,-29] ])
        self.assertEqual(mesh['faces'],[[2,1,0],[5,4,3]])

    def test_parent_scale_applies_to_the_complete_assembly_once(self):
        definitions={'ship':{'model':'hull','model_scale_factor':2,'subentities':[{'subentity_key':'engine','position':[10,0,0]}]},'engine':{'model':'engine'}}
        mesh=assembly.assembly('ship',definitions,triangle)
        self.assertEqual(mesh['vertices'][3],[22,0,0])
        self.assertEqual(mesh['vertices'][0],[2,0,0])

    def test_missing_components_and_cycles_cannot_silently_make_incomplete_ships(self):
        with self.assertRaises(KeyError):assembly.assembly('ship',{'ship':{'model':'hull','subentities':['missing 0 0 0 1 0 0 0']}},triangle)
        with self.assertRaises(AssertionError):assembly.resolved('ship',{'ship':{'like_ship':'ship'}})
        with self.assertRaises(AssertionError):assembly.assembly('ship',{'ship':{'model':'hull','subentities':['ship 0 0 0 1 0 0 0']}},triangle)

    def test_child_overrides_replace_parent_subentities(self):
        definitions={'parent':{'model':'old','subentities':['missing 0 0 0 1 0 0 0']},'child':{'like_ship':'parent','model':'new','subentities':[]}}
        self.assertEqual(assembly.assembly('child',definitions,triangle)['components'],['child'])


if __name__=='__main__':unittest.main()
