"""Preserve copied resource paths and exact bytes in either macOS bundle layout."""

import plistlib
import re
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import package_macos


class PackagedResourceTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.source = self.root / "Sources/EliteCore/Resources"
        self.app = self.root / "L337.app"
        self.bundle = self.app / "Contents/Resources/L337_EliteCore.bundle"
        self.resources = {
            "Ships/ship.toml": b"ship",
            "MissionPacks/campaign/manifest.toml": b"legacy campaign",
            "ScriptPacks/generated-couriers/manifest.toml": b"courier manifest",
            "ScriptPacks/generated-couriers/main.lua": b"courier script",
            "ScriptPacks/another-pack/manifest.toml": b"different manifest",
            "ScriptPacks/another-pack/main.lua": b"different script",
            "ShipTextures/RayDetails/texture.png": b"ray texture",
            "ShipTextures/Stingray/texture.png": b"stingray texture",
            "OriginalWorlds/catalogue.json": b"original worlds",
            "OriginalWorlds/PROVENANCE.json": b"world provenance",
            "OriginalShipTextures/texture.png": b"original ship texture",
            "OriginalFleetShowroomModels/SH084.json": b"original showroom model",
            "OriginalMarkets/catalogue.json": b"original market catalogue",
            "Legal/NOTICE.txt": b"legal notice",
            "ModelLicenses/model.txt": b"model licence",
            "ASSET-NOTICE.txt": b"asset notice",
        }
        for relative, contents in self.resources.items():
            self.write(self.source / relative, contents)
        self.root_patch = patch.object(package_macos, "ROOT", self.root)
        self.root_patch.start()
        self.addCleanup(self.root_patch.stop)

    @staticmethod
    def write(path, contents):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(contents)

    def populate_bundle(self, nested):
        destination = self.bundle / "Contents/Resources" if nested else self.bundle
        for relative, contents in self.resources.items():
            path = Path(relative)
            # SwiftPM processes these directories into the bundle's resource root.
            if path.parts[0] in ("Legal", "ModelLicenses"):
                path = Path(path.name)
            self.write(destination / path, contents)
        return destination

    def test_created_app_preserves_executable_legal_and_resource_bytes(self):
        legal = {"LICENSE": b"project licence", "NOTICE.md": b"original attribution",
                 "Resources/Elite.icns": b"existing renderer icon"}
        for relative, contents in legal.items():
            self.write(self.root / relative, contents)
        for nested in (False, True):
            with self.subTest(nested=nested):
                directory = self.root / str(nested)
                binaries = directory / "bin"
                executable = binaries / "L337"
                self.write(executable, b"fixture executable, never launched")
                executable.chmod(0o755)
                bundle = binaries / "L337_EliteCore.bundle"
                destination = bundle / "Contents/Resources" if nested else bundle
                for relative, contents in self.resources.items():
                    path = Path(relative)
                    if path.parts[0] in ("Legal", "ModelLicenses"):
                        path = Path(path.name)
                    self.write(destination / path, contents)
                app = package_macos.create_bundle(directory / "output", binaries,
                                                  "2.3.4", "a" * 40)
                self.assertEqual(app.name, "L337.app")
                delivered = app / "Contents/MacOS/L337"
                self.assertEqual(delivered.read_bytes(), executable.read_bytes())
                self.assertEqual(delivered.stat().st_mode & 0o777, 0o755)
                for relative, contents in legal.items():
                    self.assertEqual((app / "Contents/Resources" / Path(relative).name)
                                     .read_bytes(), contents)
                package_macos.verify_resources(app)
                info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
                self.assertEqual(info["CFBundleExecutable"], delivered.name)
                self.assertEqual(info["CFBundleName"], "L337")
                self.assertEqual(info["CFBundleDisplayName"], "L337")
                self.assertEqual(info["CFBundleIdentifier"], "io.xyzzy.l337")
                self.assertEqual(info["CFBundleShortVersionString"], "2.3.4")
                self.assertEqual(info["CFBundleVersion"], "2.3.4")
                self.assertEqual(info["EliteSourceRevision"], "a" * 40)
                self.assertEqual(info["LSMinimumSystemVersion"], "14.0")
                self.assertFalse((app / "Contents/MacOS/Elite").exists())

    def test_development_and_release_bundle_identity_agree(self):
        root = Path(package_macos.__file__).resolve().parents[2]
        launcher = (root / "script/build_and_run.sh").read_text()
        template = launcher.split("<<'PLIST'\n", 1)[1].split("\nPLIST", 1)[0]
        development = plistlib.loads(template.encode())
        for relative in ("Resources/Elite.icns", "LICENSE", "NOTICE.md"):
            self.write(self.root / relative, b"legal/icon fixture")
        binaries = self.root / "bin"
        self.write(binaries / "L337", b"never executed")
        (binaries / "L337_EliteCore.bundle").mkdir()
        app = package_macos.create_bundle(self.root / "output", binaries, "2.3.4", "b" * 40)
        release = plistlib.loads((app / "Contents/Info.plist").read_bytes())
        for key, value in development.items():
            with self.subTest(key=key):
                self.assertEqual(release[key], value)

    def test_copied_paths_and_processed_legal_files_survive_both_bundle_layouts(self):
        for nested in (False, True):
            with self.subTest(nested=nested):
                self.populate_bundle(nested)
                package_macos.verify_resources(self.app)

    def test_missing_copied_resource_is_rejected_in_both_layouts(self):
        for nested in (False, True):
            for relative in self.resources:
                with self.subTest(nested=nested, relative=relative):
                    destination = self.populate_bundle(nested)
                    target = destination / relative
                    if relative.startswith(("Legal/", "ModelLicenses/")):
                        target = destination / Path(relative).name
                    target.unlink()
                    with self.assertRaisesRegex(
                        RuntimeError, "Missing/changed packaged resource"
                    ):
                        package_macos.verify_resources(self.app)

    def test_changed_bytes_are_rejected_in_both_layouts(self):
        for nested in (False, True):
            for relative in self.resources:
                with self.subTest(nested=nested, relative=relative):
                    destination = self.populate_bundle(nested)
                    target = destination / relative
                    if relative.startswith(("Legal/", "ModelLicenses/")):
                        target = destination / Path(relative).name
                    target.write_bytes(b"changed")
                    with self.assertRaisesRegex(
                        RuntimeError, "Missing/changed packaged resource"
                    ):
                        package_macos.verify_resources(self.app)

    def test_flattened_copied_alias_cannot_replace_the_nested_resource(self):
        for nested in (False, True):
            for relative in (
                "ScriptPacks/generated-couriers/manifest.toml",
                "ScriptPacks/generated-couriers/main.lua",
                "ShipTextures/RayDetails/texture.png",
                "OriginalWorlds/catalogue.json",
                "OriginalShipTextures/texture.png",
                "OriginalFleetShowroomModels/SH084.json",
                "OriginalMarkets/catalogue.json",
            ):
                with self.subTest(nested=nested, relative=relative):
                    destination = self.populate_bundle(nested)
                    target = destination / relative
                    target.unlink()
                    self.write(destination / target.name, self.resources[relative])
                    with self.assertRaisesRegex(
                        RuntimeError, "Missing/changed packaged resource"
                    ):
                        package_macos.verify_resources(self.app)


class PackagedResourceManifestTests(unittest.TestCase):
    def test_copied_directories_match_the_package_manifest(self):
        manifest = Path(package_macos.__file__).resolve().parents[2] / "Package.swift"
        copied = set(
            re.findall(r'\.copy\("Resources/([^"/]+)"\)', manifest.read_text())
        )
        self.assertTrue(copied)
        self.assertEqual(set(package_macos.COPIED_RESOURCE_DIRECTORIES), copied)


if __name__ == "__main__":
    unittest.main()
