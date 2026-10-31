import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers

@testable import L337Mac

@MainActor
struct ReadmeGIFStreamTests {
  @Test func writesFramesBeforeFinishingAndDecodesEveryIndependentPalette() throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let destination = directory.appendingPathComponent("tape.gif")
    let original = Data("previous published tape".utf8)
    try original.write(to: destination)
    let stream = try ReadmeGIFStream(destination: destination, width: 8, height: 6, frameCount: 3)
    let colours: [(Double, Double, Double)] = [(1, 0, 0), (0, 1, 0), (0, 0, 1)]
    let images = [try solid(colours[0], pattern: true), try solid(colours[1]), try solid(colours[2])]
    let delays = [0.16, 0.10, 0.10]
    var length = try Data(contentsOf: stream.temporaryURL).count
    for index in colours.indices {
      let image = images[index]
      try stream.append(image, delay: delays[index])
      let current = try Data(contentsOf: stream.temporaryURL).count
      #expect(current > length)
      #expect(try Data(contentsOf: destination) == original)
      length = current
    }
    try stream.finish()
    #expect(!FileManager.default.fileExists(atPath: stream.temporaryURL.path))
    let source = try #require(CGImageSourceCreateWithURL(destination as CFURL, nil))
    #expect(CGImageSourceGetCount(source) == 3)
    let properties = try #require(CGImageSourceCopyProperties(source, nil) as? [String: Any])
    let gif = try #require(properties[kCGImagePropertyGIFDictionary as String] as? [String: Any])
    #expect((gif[kCGImagePropertyGIFLoopCount as String] as? NSNumber)?.intValue == 0)
    for index in colours.indices {
      let decoded = try #require(CGImageSourceCreateImageAtIndex(source, index, nil))
      #expect(decoded.width == 8 && decoded.height == 6)
      let pixels = try rgba(decoded)
      let reference = try rgba(images[index])
      #expect(pixels.count == reference.count)
      #expect(zip(pixels, reference).allSatisfy { abs(Int($0.0) - Int($0.1)) <= 2 })
      let frame = try #require(CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [String: Any])
      let timing = try #require(frame[kCGImagePropertyGIFDictionary as String] as? [String: Any])
      let delay = try #require(timing[kCGImagePropertyGIFDelayTime as String] as? NSNumber)
      #expect(abs(delay.doubleValue - delays[index]) < 1e-9)
    }
    #expect(throws: ReadmeGIFError.self) { try stream.finish() }
    #expect(throws: ReadmeGIFError.self) { try stream.append(try solid((1, 1, 1)), delay: 0.1) }
  }

  @Test func incompleteOrRejectedFramesCannotReplaceThePublishedTape() throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let destination = directory.appendingPathComponent("tape.gif")
    let original = Data("retain this tape".utf8)
    try original.write(to: destination)
    let stream = try ReadmeGIFStream(destination: destination, width: 8, height: 6, frameCount: 2)
    #expect(throws: ReadmeGIFError.self) {
      try stream.append(try solid((1, 0, 0), width: 4), delay: 0.1)
    }
    #expect(throws: ReadmeGIFError.self) { try stream.append(try solid((1, 0, 0)), delay: .nan) }
    try stream.append(try solid((1, 0, 0)), delay: 0.1)
    #expect(throws: ReadmeGIFError.self) { try stream.finish() }
    #expect(try Data(contentsOf: destination) == original)
    #expect(FileManager.default.fileExists(atPath: stream.temporaryURL.path))
  }

  @Test func publicationFailurePreservesTheExistingDestinationAndClosesTheWriter() throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let destination = directory.appendingPathComponent("occupied.gif", isDirectory: true)
    try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: false)
    let sentinel = destination.appendingPathComponent("keep")
    let original = Data("existing destination".utf8)
    try original.write(to: sentinel)
    let stream = try ReadmeGIFStream(destination: destination, width: 8, height: 6, frameCount: 1)
    try stream.append(try solid((0, 1, 0)), delay: 0.1)
    #expect(throws: (any Error).self) { try stream.finish() }
    #expect(try Data(contentsOf: sentinel) == original)
    #expect(FileManager.default.fileExists(atPath: stream.temporaryURL.path))
    #expect(throws: ReadmeGIFError.self) { try stream.append(try solid((1, 0, 0)), delay: 0.1) }
  }

  @Test func realSingleFramePayloadRefusesEveryTruncatedPrefixAndTrailingGarbage() throws {
    let image = try solid((0, 0, 1))
    let data = try #require(CFDataCreateMutable(nil, 0))
    let encoder = try #require(
      CGImageDestinationCreateWithData(data, UTType.gif.identifier as CFString, 1, nil))
    CGImageDestinationAddImage(encoder, image, nil)
    try #require(CGImageDestinationFinalize(encoder))
    let encoded = data as Data
    _ = try ReadmeGIFImage(data: encoded, width: 8, height: 6)
    for length in 0..<encoded.count {
      #expect(throws: ReadmeGIFError.self) {
        _ = try ReadmeGIFImage(data: Data(encoded.prefix(length)), width: 8, height: 6)
      }
    }
    #expect(throws: ReadmeGIFError.self) {
      _ = try ReadmeGIFImage(data: encoded + Data([0]), width: 8, height: 6)
    }
  }

  private func temporaryDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    return directory
  }

  private func solid(
    _ rgb: (Double, Double, Double), width: Int = 8, pattern: Bool = false
  ) throws -> CGImage {
    let context = try #require(
      CGContext(
        data: nil, width: width, height: 6, bitsPerComponent: 8, bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    context.setFillColor(CGColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: 6))
    if pattern {
      context.setFillColor(CGColor(red: 0, green: 1, blue: 0, alpha: 1))
      context.fill(CGRect(x: 4, y: 3, width: 4, height: 3))
      context.setFillColor(CGColor(red: 0, green: 0, blue: 1, alpha: 1))
      context.fill(CGRect(x: 0, y: 0, width: 4, height: 3))
    }
    return try #require(context.makeImage())
  }

  private func rgba(_ image: CGImage) throws -> [UInt8] {
    var pixel = [UInt8](repeating: 0, count: image.width * image.height * 4)
    try pixel.withUnsafeMutableBytes { bytes in
      let context = try #require(
        CGContext(
          data: bytes.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8,
          bytesPerRow: image.width * 4,
          space: CGColorSpaceCreateDeviceRGB(),
          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
      context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    }
    return pixel
  }
}
