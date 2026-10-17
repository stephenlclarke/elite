import AppKit
import Testing

@testable import EliteCore
@testable import EliteMac

@Suite(.serialized)
struct NativeShipTextureTests {
  @MainActor @Test func nativeAndBitmapExportsSampleTheSameOpaqueSourceTexel() throws {
    let texture = try #require(ShipTextureAssets.pixels(for: "sunray-diffuse"))
    let u = (123.5 / Double(texture.width))
    let v = (345.5 / Double(texture.height))
    let expected = texture.pixels[345 * texture.width + 123]
    let triangle = ShipTexturedTriangle(
      vertices: [(20.0, 20.0), (60.0, 20.0), (20.0, 60.0)].map {
        .init(point: .init($0.0, $0.1), reciprocalDepth: 1, uOverDepth: u, vOverDepth: v)
      }, texture: "sunray-diffuse", brightness: 1,
      clip: .init(x: 0, y: 12, width: 256, height: 164))
    var bitmap = Frame()
    bitmap.textured(triangle)
    #expect(bitmap.pixels[25 * 256 + 25] == expected)
    var native = Frame()
    native.rasterizeGraphics = false
    native.textured(triangle)
    let image = try #require(imageFor(native))
    let data = try #require(image.dataProvider?.data)
    let bytes = try #require(CFDataGetBytePtr(data))
    let offset = 25 * image.bytesPerRow + 25 * 4
    #expect(bytes[offset] == UInt8((expected >> 24) & 255))
    #expect(bytes[offset + 1] == UInt8((expected >> 16) & 255))
    #expect(bytes[offset + 2] == UInt8((expected >> 8) & 255))
    #expect(bytes[offset + 3] == 255)
    let retina = try #require(imageFor(native, pixelSize: 512))
    let retinaData = try #require(retina.dataProvider?.data)
    let retinaBytes = try #require(CFDataGetBytePtr(retinaData))
    let retinaOffset = 51 * retina.bytesPerRow + 51 * 4
    #expect(retinaBytes[retinaOffset] == bytes[offset])
    #expect(retinaBytes[retinaOffset + 1] == bytes[offset + 1])
    #expect(retinaBytes[retinaOffset + 2] == bytes[offset + 2])
  }

  @MainActor @Test func asymmetricUVsKeepNativeAndBitmapRowsAndTransparentEdgesAligned() throws {
    let triangle = ShipTexturedTriangle(
      vertices: [
        .init(point: .init(20, 20), reciprocalDepth: 1, uOverDepth: 0.12, vOverDepth: 0.2),
        .init(point: .init(60, 20), reciprocalDepth: 1, uOverDepth: 0.8, vOverDepth: 0.15),
        .init(point: .init(20, 60), reciprocalDepth: 1, uOverDepth: 0.2, vOverDepth: 0.9),
      ], texture: "sunray-diffuse", brightness: 1,
      clip: .init(x: 0, y: 12, width: 256, height: 164))
    var bitmap = Frame()
    bitmap.textured(triangle)
    var native = Frame()
    native.rasterizeGraphics = false
    native.textured(triangle)
    let image = try #require(imageFor(native))
    let data = try #require(image.dataProvider?.data)
    let bytes = try #require(CFDataGetBytePtr(data))
    var sampled: Set<UInt32> = []
    for y in stride(from: 22, to: 60, by: 4) {
      for x in stride(from: 22, to: 60, by: 4) {
        let expected = bitmap.pixels[y * 256 + x]
        let offset = y * image.bytesPerRow + x * 4
        #expect(bytes[offset] == UInt8((expected >> 24) & 255))
        #expect(bytes[offset + 1] == UInt8((expected >> 16) & 255))
        #expect(bytes[offset + 2] == UInt8((expected >> 8) & 255))
        sampled.insert(expected)
      }
    }
    #expect(sampled.count > 8)
    #expect(bitmap.pixels[55 * 256 + 55] == Ink.black.rawValue)
  }

  @MainActor @Test func bothSelectedTexturedShipsRenderThroughActualShowroomAtNativeSizes() throws {
    var game = Game(executive: false)
    game.screen = .showroom
    game.commander.shipDisplayStyle = .shadedPanels
    for id in ["SH169", "SH170"] {
      game.showroom.selection = id
      for (width, height) in [(512, 518), (1512, 982)] {
        let frame = Display.presentation(game, width: Double(width), height: Double(height))
        let triangles = (frame.worldGraphics + frame.graphics).compactMap {
          graphic -> ShipTexturedTriangle? in
          if case .textured(let triangle) = graphic { return triangle }
          return nil
        }
        #expect(!triangles.isEmpty)
        #expect(
          triangles.allSatisfy {
            $0.vertices.allSatisfy { $0.point.x.isFinite && $0.point.y.isFinite }
          })
        let image = try #require(imageForGame(game, width: width, height: height))
        #expect(image.width == width && image.height == height)
        #expect(image.dataProvider?.data != nil)
      }
    }
  }
}
