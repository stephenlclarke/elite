"""The selected PNG alpha channel must not erase visible hull RGB during preparation."""
import importlib.util
from pathlib import Path
import struct
import unittest
import zlib

spec = importlib.util.spec_from_file_location('prepare_textures', Path(__file__).with_name('prepare-ship-textures.py'))
prepare = importlib.util.module_from_spec(spec)
spec.loader.exec_module(prepare)


def chunk(kind, data):
    return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data) & 0xffffffff)


def fixture(width=2, interlace=0):
    header = struct.pack('>IIBBBBB', width, 1, 8, 6, 0, 0, interlace)
    # These are straight, unpremultiplied PNG samples: transparent red must survive.
    row = bytes([0, 255, 0, 0, 0, 0, 0, 255, 128])
    return b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', header) + chunk(b'IDAT', zlib.compress(row)) + chunk(b'IEND', b'')


class ShipTexturePreparationTests(unittest.TestCase):
    def test_specular_alpha_does_not_premultiply_or_remove_original_rgb(self):
        width, height, pixels = prepare.opaque_rgba(fixture())
        self.assertEqual((width, height), (2, 1))
        self.assertEqual(pixels, bytes([255, 0, 0, 255, 0, 0, 255, 255]))

    def test_corrupt_unsupported_and_oversized_pngs_refuse_before_pixel_publication(self):
        corrupt = bytearray(fixture())
        corrupt[-1] ^= 1
        for png in [b'not png', bytes(corrupt), fixture(width=2049), fixture(interlace=1),
                    fixture()[:-8], fixture()[:-12], fixture() + b'trailing',
                    fixture()[:-12] + chunk(b'IEND', b'not empty')]:
            with self.subTest(size=len(png)), self.assertRaises((AssertionError, struct.error, TypeError)):
                prepare.opaque_rgba(png)


if __name__ == '__main__':
    unittest.main()
