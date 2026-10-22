"""Dependency regressions for individual TOML media and complete runtime data."""
import importlib.util
import hashlib
import tempfile
from pathlib import Path
import unittest
from unittest.mock import patch
import tomllib

spec=importlib.util.spec_from_file_location('ship_reference',Path(__file__).with_name('ship-reference.py'))
reference=importlib.util.module_from_spec(spec)
spec.loader.exec_module(reference)


class ShipReferenceTests(unittest.TestCase):
    def render_root(self, root):
        for name in reference.RENDER_FILES:
            path = root/name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b'unchanged renderer')
        (root/'Sources/EliteCore/Game.swift').write_text(
            '// unrelated mission before\n' + reference.VIEW_START
            + '    return p\n  }\n' + reference.VIEW_END + '// unrelated mission after\n')

    def test_each_declared_renderer_dependency_invalidates_and_missing_files_fail_closed(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            self.render_root(root)
            original = reference.shared_hash(root)
            for name in reference.RENDER_FILES:
                with self.subTest(dependency=name):
                    path = root/name
                    before = path.read_bytes()
                    path.write_bytes(before + b'changed')
                    self.assertNotEqual(reference.shared_hash(root), original)
                    path.unlink()
                    with self.assertRaises(FileNotFoundError):
                        reference.shared_hash(root)
                    path.write_bytes(before)
                    self.assertEqual(reference.shared_hash(root), original)

    def test_unrelated_mission_custody_and_game_methods_do_not_invalidate_portraits(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            self.render_root(root)
            original = reference.shared_hash(root)
            for name in ['NativeSafeGunneryRuntime.swift', 'NativeIsolationProgrammerCustody.swift',
                         'NativeWayfarerInductionCrewLogSave.swift']:
                path = root/'Sources/EliteCore'/name
                path.write_bytes(b'new mission')
                self.assertEqual(reference.shared_hash(root), original)
                path.write_bytes(b'changed custody')
                self.assertEqual(reference.shared_hash(root), original)
                path.unlink()
                self.assertEqual(reference.shared_hash(root), original)
            game = root/'Sources/EliteCore/Game.swift'
            game.write_text(game.read_text().replace('unrelated mission', 'new service state'))
            self.assertEqual(reference.shared_hash(root), original)

    def test_actual_view_transform_invalidates_and_moved_or_ambiguous_boundary_fails_closed(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            self.render_root(root)
            path = root/'Sources/EliteCore/Game.swift'
            source = path.read_text()
            original = reference.shared_hash(root)
            path.write_text(source.replace('return p', 'return p * 2'))
            self.assertNotEqual(reference.shared_hash(root), original)
            for text in [source.replace(reference.VIEW_START, ''),
                         source.replace(reference.VIEW_END, ''),
                         source + reference.VIEW_START,
                         reference.VIEW_END + source.replace(reference.VIEW_END, '')]:
                path.write_text(text)
                with self.assertRaises(ValueError):
                    reference.shared_hash(root)

    def test_settings_and_relative_dependency_identity_are_content_based(self):
        with tempfile.TemporaryDirectory() as a, tempfile.TemporaryDirectory() as b:
            first, second = Path(a), Path(b)
            self.render_root(first)
            self.render_root(second)
            original = reference.shared_hash(first)
            self.assertEqual(reference.shared_hash(second), original)
            (first/reference.RENDER_FILES[0]).touch()
            self.assertEqual(reference.shared_hash(first), original)
            with patch.object(reference, 'SETTINGS', reference.SETTINGS + b':new-frame-rate'):
                self.assertNotEqual(reference.shared_hash(first), original)

    def test_both_texture_trees_track_pixels_manifests_notices_and_renamed_or_deleted_inputs(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            self.render_root(root)
            for directory in reference.TEXTURE_FOLDERS:
                textures = root/directory
                before_empty = reference.shared_hash(root)
                textures.mkdir(parents=True)
                self.assertEqual(reference.shared_hash(root), before_empty)
                for name in ['diffuse.png', 'diffuse.rgba', 'manifest.json', 'NOTICE.md']:
                    with self.subTest(folder=directory, dependency=name):
                        before = reference.shared_hash(root)
                        path = textures/name
                        path.write_bytes(b'original bytes')
                        added = reference.shared_hash(root)
                        self.assertNotEqual(added, before)
                        path.write_bytes(b'changed bytes')
                        changed = reference.shared_hash(root)
                        self.assertNotEqual(changed, added)
                        renamed = path.with_name('renamed-' + name)
                        path.rename(renamed)
                        self.assertNotEqual(reference.shared_hash(root), changed)
                        renamed.unlink()
                        self.assertEqual(reference.shared_hash(root), before)

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
        self.assertEqual(sum(ship['id'] == 'SH025' for ship in ships), 1)
        original = next(ship for ship in ships if ship['id'] == 'SH025')
        self.assertEqual(original['name'], 'Peregrine Mk V')
        self.assertEqual(original['catalogue']['family'], 'peregrine')
        self.assertEqual([profile['id'] for profile in original['profiles']], ['L337-PLAYER-SH025'])
        self.assertEqual((original['game']['cargo'], original['game']['cargoExpansion']), (92, 35))
        self.assertNotIn('recipe', original['design'])
        self.assertEqual(
            hashlib.sha256((reference.ship_files.SHIP_FOLDER / 'SH025.toml').read_bytes()).hexdigest(),
            '794c19f74e633c5837ad78705398cf74f349b1ca4854b22bb3257d23bcb4059a',
        )
        self.assertEqual(sum('recipe' in s['design'] for s in ships),93)
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
