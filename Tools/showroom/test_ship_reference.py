"""Dependency regressions for individual TOML media and complete runtime data."""
import importlib.util
import tempfile
from pathlib import Path
import unittest
import tomllib

spec=importlib.util.spec_from_file_location('ship_reference',Path(__file__).with_name('ship-reference.py'))
reference=importlib.util.module_from_spec(spec)
spec.loader.exec_module(reference)


class ShipReferenceTests(unittest.TestCase):
    def test_content_dependencies_and_unchanged_reuse(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);spec_a=root/'SH001.toml';spec_b=root/'SH002.toml';gif=root/'SH001.gif'
            spec_a.write_text('name = "Adder"\n');spec_b.write_text('name = "Other"\n');gif.write_bytes(b'GIF89a')
            previous={'input':reference.fingerprint(spec_a.read_bytes(),'renderer1'),'output':reference.digest(gif.read_bytes())}
            self.assertFalse(reference.needs_render(spec_a,'renderer1',previous,gif))
            spec_b.write_text('name = "Changed other ship"\n')
            self.assertFalse(reference.needs_render(spec_a,'renderer1',previous,gif))
            spec_a.write_text('name = "Adder"\n[game]\nspeed = 99\n')
            self.assertTrue(reference.needs_render(spec_a,'renderer1',previous,gif))
            previous['input']=reference.fingerprint(spec_a.read_bytes(),'renderer1')
            spec_a.write_text(spec_a.read_text()+'[design]\nvertices = [[1,2,3]]\n')
            self.assertTrue(reference.needs_render(spec_a,'renderer1',previous,gif))
            previous['input']=reference.fingerprint(spec_a.read_bytes(),'renderer1')
            self.assertTrue(reference.needs_render(spec_a,'renderer2',previous,gif))
            gif.write_bytes(b'corrupted')
            self.assertTrue(reference.needs_render(spec_a,'renderer1',previous,gif))
            gif.unlink()
            self.assertTrue(reference.needs_render(spec_a,'renderer1',previous,gif))

    def test_all_runtime_definitions_include_geometry_and_preserve_source_profiles(self):
        ships=reference.ship_files.read_ships()
        self.assertEqual(len(ships),171)
        self.assertEqual(sum('game' in s for s in ships),162)
        self.assertEqual(sum('recipe' in s['design'] for s in ships),94)
        originals=[]
        for ship in ships:
            design=ship['design'];vertices=design['vertices']
            self.assertTrue(all(len(p)==3 for p in vertices))
            self.assertTrue(all(len(f)>=3 and all(0<=v<len(vertices) for v in f) for f in design['faces']))
            self.assertTrue(design['license'] and ship['profiles'])
            if 'recipe' in design:
                # Normalised coordinate ratios must differ, beyond merely scaling a generic box.
                spans=[max(p[i] for p in vertices)-min(p[i] for p in vertices) for i in range(3)]
                originals.append(reference.digest(str([[round(p[i]/spans[i],5) for i in range(3)] for p in vertices]).encode()))
        self.assertEqual(len(originals),len(set(originals)))


if __name__=='__main__':unittest.main()
