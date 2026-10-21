#!/usr/bin/env python3
"""Prepare the three pinned Commies Ray diffuse images without premultiplying specular alpha."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import struct
import zipfile
import zlib

ARCHIVE_SHA = '09d478852cf2485e3a1e8be2ebca9d8771ea13af08ac977010a7c07fb8a42e4a'
ASSETS = [
    ('sunray-diffuse', 'comray_sun.png', '4715eb73f1c2d1dec673f0c8f7763c17bd5fc6cf1de87a5a6503e2d55bae163a'),
    ('stingray-diffuse', 'comrayii.png', '62e48e92685f18ef7682768bab9a34fdcf0f92fd119425fcc92bd73dccd7a843'),
    ('ray-details', 'commies_details.png', '5c72460f1dd6315ac6e7970cd31e70dc2977e552675518cdd7f9f660fa4b6a2a'),
]


def module(name, filename):
    spec = importlib.util.spec_from_file_location(name, Path(__file__).with_name(filename))
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


def opaque_rgba(png):
    """Decode bounded noninterlaced 8-bit RGB(A); source alpha is a specular channel."""
    assert png[:8] == b'\x89PNG\r\n\x1a\n'
    offset, chunks, header, terminal = 8, [], None, False
    while offset < len(png):
        size = struct.unpack('>I', png[offset:offset + 4])[0]
        kind = png[offset + 4:offset + 8]
        data = png[offset + 8:offset + 8 + size]
        crc = png[offset + 8 + size:offset + 12 + size]
        assert len(data) == size and len(crc) == 4
        assert zlib.crc32(kind + data) & 0xffffffff == struct.unpack('>I', crc)[0]
        if kind == b'IHDR':
            assert header is None
            header = struct.unpack('>IIBBBBB', data)
        elif kind == b'IDAT':
            chunks.append(data)
        elif kind == b'IEND':
            assert size == 0 and offset + 12 == len(png)
            terminal = True
            break
        offset += size + 12
    assert terminal
    width, height, bits, colour, compression, filtering, interlace = header
    assert 0 < width <= 2048 and 0 < height <= 2048
    assert bits == 8 and colour in (2, 6) and (compression, filtering, interlace) == (0, 0, 0)
    channels = 3 if colour == 2 else 4
    stride = width * channels
    decoder = zlib.decompressobj()
    raw = decoder.decompress(b''.join(chunks), (stride + 1) * height + 1)
    assert decoder.eof and not decoder.unused_data and len(raw) == (stride + 1) * height
    result, previous = bytearray(), bytearray(stride)
    for y in range(height):
        start = y * (stride + 1)
        mode, row = raw[start], bytearray(raw[start + 1:start + 1 + stride])
        assert 0 <= mode <= 4
        for x in range(stride):
            left = row[x - channels] if x >= channels else 0
            above = previous[x]
            corner = previous[x - channels] if x >= channels else 0
            prediction = left + above - corner
            distances = [abs(prediction - left), abs(prediction - above), abs(prediction - corner)]
            paeth = [left, above, corner][distances.index(min(distances))]
            predictor = [0, left, above, (left + above) // 2, paeth][mode]
            row[x] = (row[x] + predictor) & 255
        for x in range(0, stride, channels):
            result.extend(row[x:x + 3])
            result.append(255)
        previous = row
    return width, height, bytes(result)


def prepare(archive_path, output):
    archive_bytes = archive_path.read_bytes()
    assert hashlib.sha256(archive_bytes).hexdigest() == ARCHIVE_SHA
    output.mkdir(parents=True, exist_ok=True)
    records = []
    bindings, source_members = [], {}
    with zipfile.ZipFile(archive_path) as archive:
        appearance = module('texture_appearance', 'source-appearance.py')
        expansion = module('texture_expansion', 'expansion-models.py')
        definitions, source_members = expansion.source_definitions(archive)
        by_filename = {filename: identity for identity, filename, _ in ASSETS}
        for definition, expected_model, expected_assets in [
            ('sunray-player', 'ac6723c2e1b49e12a031f6c5deed687f52e86cbd63cfa72df2abad2028152936', ['sunray-diffuse', 'ray-details']),
            ('commilray-player', 'a29d506bf62198fdacb220b6086f2bd2983134137802a4e1cac0f88442b0bd1c', ['stingray-diffuse', 'ray-details']),
        ]:
            model = 'Models/' + expansion.resolved(definition, definitions)['model']
            model_bytes = archive.read(model)
            digest = hashlib.sha256(model_bytes).hexdigest()
            assert digest == expected_model
            source_members[model] = digest
            names = appearance.resolved_texture_names(model_bytes.decode().splitlines(), ['0', '1'])
            selected = [by_filename[appearance.resolved_diffuse_map(definitions, definition, name)] for name in names]
            assert selected == expected_assets
            bindings.append(dict(definition=definition, modelSHA256=digest, materials=names, assets=selected))
        for identity, filename, digest in ASSETS:
            member = 'Textures/' + filename
            png = archive.read(member)
            assert hashlib.sha256(png).hexdigest() == digest
            width, height, pixels = opaque_rgba(png)
            (output / (identity + '.png')).write_bytes(png)
            (output / (identity + '.rgba')).write_bytes(pixels)
            records.append(dict(id=identity, member=member, pngSHA256=digest,
                                rgbaSHA256=hashlib.sha256(pixels).hexdigest(),
                                width=width, height=height, license='CC-BY-NC-SA-3.0'))
        for member, filename in [('README.txt', 'SOURCE-README.txt'), ('manifest.plist', 'SOURCE-manifest.plist')]:
            data = archive.read(member)
            source_members[member] = hashlib.sha256(data).hexdigest()
            (output / filename).write_bytes(data)
    manifest = dict(version=1, archiveSHA256=ARCHIVE_SHA, assets=records,
                    bindings=bindings, sourceMembers=source_members)
    (output / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archive', type=Path)
    parser.add_argument('--output', type=Path, default=Path('Sources/EliteCore/Resources/ShipTextures'))
    args = parser.parse_args()
    prepare(args.archive, args.output)
