import copy
import importlib.util
import json
from pathlib import Path
import struct
import tempfile
import unittest
import zlib

SPEC = importlib.util.spec_from_file_location("textures", Path(__file__).resolve().parents[1] / "prepare-original-ship-textures.py")
TOOL = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(TOOL)


def png(pixels=b"\x11\x22\x33\xff", width=1, height=1):
    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(b"\0" + pixels)) + chunk(b"IEND", b"")


class OriginalTextureTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.source = self.root / "source"
        self.source.mkdir()
        assets = []
        for identity in sorted(TOOL.ASSET_IDS):
            image = png()
            cache = b"\x11\x22\x33\xff"
            (self.source / (identity + ".png")).write_bytes(image)
            (self.source / (identity + ".rgba")).write_bytes(cache)
            asset = {"id": identity, "file": "original-textures/" + identity + ".png", "cacheFile": "original-textures/" + identity + ".rgba", "width": 1, "height": 1, "license": "MIT", "authorship": "Original fixture", "sha256": TOOL.sha(image), "cacheSHA256": TOOL.sha(cache), "auxiliarySHA256": {}}
            for kind in TOOL.AUXILIARY:
                asset[kind + "File"] = asset["file"]
                asset["auxiliarySHA256"][kind] = TOOL.sha(image)
            assets.append(asset)
        self.manifest = {"assets": assets, "bindings": {"SH001": ["l337-service-details"]}}
        self.write_manifest()

    def write_manifest(self):
        (self.source / "manifest.json").write_text(json.dumps(self.manifest))

    def test_exact_pixels_and_deterministic_bundle(self):
        first, second = self.root / "one", self.root / "two"
        a = TOOL.prepare(self.source, first)
        b = TOOL.prepare(self.source, second)
        self.assertEqual(a, b)
        for path in first.iterdir():
            self.assertEqual(path.read_bytes(), (second / path.name).read_bytes())
        self.assertEqual(TOOL.diffuse_pixels(png()), (1, 1, b"\x11\x22\x33\xff"))
        with self.assertRaises(ValueError):
            TOOL.prepare(self.source, first)

    def test_corruption_hash_and_pixel_disagreement_refused(self):
        for mutation in ("crc", "hash", "pixel", "missing", "duplicate"):
            with self.subTest(mutation=mutation):
                data = copy.deepcopy(self.manifest)
                asset = data["assets"][0]
                path = self.source / (asset["id"] + ".png")
                if mutation == "crc":
                    path.write_bytes(png()[:-1] + b"x")
                elif mutation == "hash":
                    asset["sha256"] = "0" * 64
                elif mutation == "pixel":
                    cache = b"\xaa\xbb\xcc\xff"
                    (self.source / (asset["id"] + ".rgba")).write_bytes(cache)
                    asset["cacheSHA256"] = TOOL.sha(cache)
                elif mutation == "missing":
                    asset["file"] = "original-textures/missing.png"
                else:
                    data["assets"][1] = asset
                (self.source / "manifest.json").write_text(json.dumps(data))
                with self.assertRaises((ValueError, OSError)):
                    TOOL.prepare(self.source, self.root / mutation)
                path.write_bytes(png())
                (self.source / (asset["id"] + ".rgba")).write_bytes(b"\x11\x22\x33\xff")

    def test_path_symlink_and_dimensions_refused(self):
        for path in ("original-textures/../escape", "../escape", "/absolute", "original-textures/evil\\file"):
            data = copy.deepcopy(self.manifest)
            data["assets"][0]["file"] = path
            (self.source / "manifest.json").write_text(json.dumps(data))
            with self.assertRaises(ValueError):
                TOOL.prepare(self.source, self.root / ("out" + str(len(path))))
        self.write_manifest()
        destination = self.root / "destination"
        destination.mkdir()
        link = self.root / "link"
        link.symlink_to(destination, target_is_directory=True)
        with self.assertRaises(ValueError):
            TOOL.prepare(self.source, link)
        self.assertEqual(list(destination.iterdir()), [])
        with self.assertRaises(ValueError):
            TOOL.diffuse_pixels(png(width=2049))

    def test_actual_hull_reference_wins_and_untextured_uv_is_preserved(self):
        folder = self.root / "hulls"
        folder.mkdir()
        text = 'proposal = {id = "SH001"}\ndesign = {faces = [[0,1,2]], textures = [], faceTextures = [{texture = -1, uv = [[0.0,0.0],[0.0,0.0],[0.0,0.0]]}]}\n'
        (folder / "SH001-design.toml").write_text(text)
        inventory = TOOL.hull_inventory(folder, self.manifest, expected=1)
        self.assertEqual(inventory["hulls"][0]["designs"]["design"]["untexturedCornerUVs"], 1)
        self.assertEqual(inventory["manifestBindingDifferences"][0]["actual"], [])
        self.assertEqual((folder / "SH001-design.toml").read_text(), text)

    def test_unused_declared_texture_is_not_an_actual_face_binding(self):
        folder = self.root / "hulls"
        folder.mkdir()
        text = 'proposal = {id = "SH169"}\ndesign = {faces = [[0,1,2]], textures = [{asset = "l337-patrol-diffuse", license = "MIT", repeat = true}, {asset = "l337-service-details", license = "MIT", repeat = true}], faceTextures = [{texture = 0, uv = [[0.0,0.0],[1.0,0.0],[0.0,1.0]]}]}\n'
        (folder / "SH169-design.toml").write_text(text)
        result = TOOL.hull_inventory(folder, {"bindings": {"SH169": ["l337-patrol-diffuse", "l337-service-details"]}}, expected=1)
        self.assertEqual(result["hulls"][0]["designs"]["design"]["usedAssets"], ["l337-patrol-diffuse"])
        self.assertEqual(result["manifestBindingDifferences"][0]["actual"], ["l337-patrol-diffuse"])


if __name__ == "__main__":
    unittest.main()
