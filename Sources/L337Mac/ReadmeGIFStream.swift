import CoreGraphics
import Darwin
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum ReadmeGIFError: Error {
  case invalidState, invalidImage, invalidData, encodingFailed
}

/// Finalize one ImageIO image at a time; never give a destination the whole tape.
/// Full-canvas game rasters have an opaque black background (NativeGraphics.swift).
@MainActor
final class ReadmeGIFStream {
  let temporaryURL: URL
  private let destination: URL
  private let width: Int
  private let height: Int
  private let expectedFrames: Int
  private var file: FileHandle?
  private var writtenFrames = 0

  init(destination: URL, width: Int, height: Int, frameCount: Int) throws {
    guard (1...65535).contains(width), (1...65535).contains(height), frameCount > 0 else {
      throw ReadmeGIFError.invalidImage
    }
    self.destination = destination
    self.width = width
    self.height = height
    expectedFrames = frameCount
    temporaryURL = destination.deletingLastPathComponent().appendingPathComponent(
      "." + destination.lastPathComponent + "-" + UUID().uuidString)
    let descriptor = Darwin.open(temporaryURL.path, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC, 0o644)
    guard descriptor >= 0 else { throw Self.posixError() }
    let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
    file = handle
    do {
      // A black global background; every image carries its own complete colour table.
      var header = Data("GIF89a".utf8)
      header.append(contentsOf: Self.word(width) + Self.word(height) + [0xF0, 0, 0])
      header.append(Data(repeating: 0, count: 6))
      header.append(contentsOf: [0x21, 0xFF, 11])
      header.append(Data("NETSCAPE2.0".utf8))
      header.append(contentsOf: [3, 1, 0, 0, 0])  // Infinite looping.
      try handle.write(contentsOf: header)
    } catch {
      file = nil
      try? handle.close()
      throw error
    }
  }

  deinit { try? file?.close() }

  func append(_ image: CGImage, delay: Double) throws {
    guard let handle = file, writtenFrames < expectedFrames else {
      throw ReadmeGIFError.invalidState
    }
    guard image.width == width, image.height == height, delay.isFinite,
      delay > 0, delay * 100 <= 65535, (delay * 100).rounded() >= 1
    else { throw ReadmeGIFError.invalidImage }
    let frame = try autoreleasepool {
      guard let data = CFDataCreateMutable(nil, 0),
        let encoder = CGImageDestinationCreateWithData(
          data, UTType.gif.identifier as CFString, 1, nil)
      else { throw ReadmeGIFError.encodingFailed }
      CGImageDestinationAddImage(encoder, image, nil)
      guard CGImageDestinationFinalize(encoder) else { throw ReadmeGIFError.encodingFailed }
      return try ReadmeGIFImage(data: data as Data, width: width, height: height)
    }
    let ticks = Int((delay * 100).rounded())
    // Disposal 2 restores black before the next full image; retain any encoded transparency index.
    let flags: UInt8 = frame.transparentIndex == nil ? 8 : 9
    let control = Data(
      [0x21, 0xF9, 4, flags] + Self.word(ticks) + [frame.transparentIndex ?? 0, 0])
    do {
      try handle.write(contentsOf: frame.extensions)
      try handle.write(contentsOf: control)
      try handle.write(contentsOf: frame.imageBlock)
      writtenFrames += 1
    } catch {
      file = nil  // A partial write cannot later be published as a valid frame.
      try? handle.close()
      throw error
    }
  }

  func finish() throws {
    guard let handle = file, writtenFrames == expectedFrames else {
      throw ReadmeGIFError.invalidState
    }
    file = nil
    do {
      try handle.write(contentsOf: Data([0x3B]))
      try handle.synchronize()
      try handle.close()
      // Same-directory rename publishes all frames atomically; old output survives any earlier error.
      guard Darwin.rename(temporaryURL.path, destination.path) == 0 else {
        throw Self.posixError()
      }
    } catch {
      try? handle.close()
      throw error
    }
  }

  private static func word(_ value: Int) -> [UInt8] {
    [UInt8(value & 255), UInt8((value >> 8) & 255)]
  }

  private static func posixError() -> NSError {
    NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
  }
}

/// Copy the already-quantized palette and LZW subblocks, without decoding or re-encoding pixels.
/// GIF89a image/control/table layout: https://www.w3.org/Graphics/GIF/spec-gif89a.txt
struct ReadmeGIFImage {
  let extensions: Data
  let transparentIndex: UInt8?
  let imageBlock: Data

  init(data: Data, width: Int, height: Int) throws {
    var reader = ReadmeGIFBytes(data: data)
    let global = try reader.header(width: width, height: height)
    let control = try reader.extensions()
    var descriptor = [UInt8](try reader.take(10))
    guard descriptor[0] == 0x2C,
      descriptor[1...4].allSatisfy({ $0 == 0 }),
      Int(descriptor[5]) | (Int(descriptor[6]) << 8) == width,
      Int(descriptor[7]) | (Int(descriptor[8]) << 8) == height,
      descriptor[9] & 0x18 == 0
    else { throw ReadmeGIFError.invalidData }
    let palette: Data
    if descriptor[9] & 0x80 != 0 {
      palette = try reader.take(3 << (Int(descriptor[9] & 7) + 1))
    } else {
      guard !global.palette.isEmpty else { throw ReadmeGIFError.invalidData }
      palette = global.palette
      // Interlace is unchanged. An unsorted local table has exactly the old global indices.
      descriptor[9] = (descriptor[9] & 0x40) | 0x80 | global.size
    }
    if let index = control.transparentIndex, Int(index) >= palette.count / 3 {
      throw ReadmeGIFError.invalidData
    }
    var block = Data(descriptor)
    block.append(palette)
    let codeSize = try reader.take(1)
    guard let bits = codeSize.first, (2...8).contains(bits) else {
      throw ReadmeGIFError.invalidData
    }
    block.append(codeSize)
    block.append(try reader.subblocks())
    guard try reader.byte() == 0x3B, reader.atEnd else { throw ReadmeGIFError.invalidData }
    extensions = control.data
    transparentIndex = control.transparentIndex
    imageBlock = block
  }
}

private struct ReadmeGIFBytes {
  let bytes: [UInt8]
  private var offset = 0
  var atEnd: Bool { offset == bytes.count }

  init(data: Data) { bytes = Array(data) }

  mutating func byte() throws -> UInt8 {
    guard offset < bytes.count else { throw ReadmeGIFError.invalidData }
    defer { offset += 1 }
    return bytes[offset]
  }

  mutating func take(_ count: Int) throws -> Data {
    guard count >= 0, count <= bytes.count, offset <= bytes.count - count else {
      throw ReadmeGIFError.invalidData
    }
    defer { offset += count }
    return Data(bytes[offset..<(offset + count)])
  }

  mutating func header(width: Int, height: Int) throws -> (palette: Data, size: UInt8) {
    let signature = try take(6)
    guard signature == Data("GIF87a".utf8) || signature == Data("GIF89a".utf8) else {
      throw ReadmeGIFError.invalidData
    }
    let dimensions = [UInt8](try take(4))
    guard Int(dimensions[0]) | (Int(dimensions[1]) << 8) == width,
      Int(dimensions[2]) | (Int(dimensions[3]) << 8) == height
    else { throw ReadmeGIFError.invalidData }
    let packed = try byte()
    _ = try take(2)  // Source background index/aspect do not replace the game's black canvas.
    let palette = try take(packed & 0x80 == 0 ? 0 : 3 << (Int(packed & 7) + 1))
    return (palette, packed & 7)
  }

  mutating func subblocks() throws -> Data {
    let start = offset
    while true {
      let count = Int(try byte())
      if count == 0 { return Data(bytes[start..<offset]) }
      _ = try take(count)
    }
  }

  mutating func extensions() throws -> (data: Data, transparentIndex: UInt8?) {
    var result = Data()
    var transparentIndex: UInt8?
    while offset < bytes.count && bytes[offset] == 0x21 {
      let start = offset
      _ = try byte()
      let label = try byte()
      if label == 0xF9 {
        guard try byte() == 4 else { throw ReadmeGIFError.invalidData }
        let control = [UInt8](try take(4))
        guard control[0] & 0xE2 == 0, (control[0] >> 2) & 7 <= 3, try byte() == 0 else {
          throw ReadmeGIFError.invalidData
        }
        transparentIndex = control[0] & 1 == 0 ? nil : control[3]
      } else {
        // Plain text is another graphic, outside this single raster-frame contract.
        guard label == 0xFE || label == 0xFF else { throw ReadmeGIFError.invalidData }
        let blocks = try subblocks()
        let loop = label == 0xFF && blocks.count >= 12 && blocks.first == 11
          && blocks.dropFirst().prefix(11) == Data("NETSCAPE2.0".utf8)
        if !loop { result.append(Data(bytes[start..<offset])) }
      }
    }
    return (result, transparentIndex)
  }
}
