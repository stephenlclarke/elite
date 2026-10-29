"""Preserve copied resource paths and exact bytes in either macOS bundle layout."""

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
        self.app = self.root / "Elite.app"
        self.bundle = self.app / "Contents/Resources/Elite_EliteCore.bundle"
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
