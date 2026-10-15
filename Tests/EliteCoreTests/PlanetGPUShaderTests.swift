import AppKit
import Darwin
import Foundation
import Testing

@testable import EliteCore
@testable import EliteMac

private func planetShaderBytes(_ image: CGImage) throws -> Data {
  let data = try #require(image.dataProvider?.data)
  return data as Data
}

@Suite(
  .enabled(if: ProcessInfo.processInfo.environment["ELITE_PLANET_GPU_EXPERIMENT"] == "1"),
  .serialized)
struct PlanetGPUShaderTests {
  @MainActor private static var compiled: CompiledPlanetPipeline?

  @MainActor private static func makeShader() async throws -> PlanetGPUShader {
    if compiled == nil { compiled = await PlanetGPUShader.compile() }
    return PlanetGPUShader(pipeline: try #require(compiled))
  }

  @MainActor @Test func invalidBoundsAndAnglesReturnCPUFallback() async throws {
    let shader = try await Self.makeShader()
    let game = Game(executive: false)
    let identity = PlanetIdentity(galaxy: 0, system: game.currentSystem)
    let terrain = PlanetTerrain(identity: identity)
    let palette = PlanetPalette(identity: identity)
    for diameter in [0, 31, 769, Int.max] {
      #expect(
        shader.image(
          identity: identity, terrain: terrain, palette: palette, angle: 0, diameter: diameter)
          == nil)
    }
    for angle in [Double.nan, .infinity, -.infinity, Double.greatestFiniteMagnitude] {
      #expect(
        shader.image(
          identity: identity, terrain: terrain, palette: palette, angle: angle, diameter: 128)
          == nil)
    }
    let smallest = try #require(
      shader.image(
        identity: identity, terrain: terrain, palette: palette, angle: 0, diameter: 32))
    #expect(smallest.width == 32 && smallest.height == 32)
    #expect(!shader.deviceName.isEmpty)
  }

  @MainActor @Test func allPalettesMatchStableCPUReferenceIncludingWrappedLongitudeAndAlpha()
    async throws
  {
    let shader = try await Self.makeShader()
    let systems = Universe.galaxy(number: 0)
    var representatives: [Int: StarSystem] = [0: systems[7]]
    for system in systems {
      let identity = PlanetIdentity(galaxy: 0, system: system)
      let variant = system.id == 7 ? 0 : Int(identity.key % 4)
      if representatives[variant] == nil { representatives[variant] = system }
    }
    #expect(representatives.count == 4)
    for variant in representatives.keys.sorted() {
      let system = try #require(representatives[variant])
      let identity = PlanetIdentity(galaxy: 0, system: system)
      let terrain = PlanetTerrain(identity: identity)
      let palette = PlanetPalette(identity: identity)
      for diameter in [128, 512, 768] {
        for phase in [0, 37, 1046] {
          let preview = PlanetPreview(
            galaxy: 0, system: system,
            bounds: .init(x: 0, y: 0, width: Double(diameter), height: Double(diameter)),
            time: (Double(phase) * 0.006 + 0.000000001) / 0.025)
          let reference = try #require(
            PlanetRenderer.referenceImage(for: preview, diameter: diameter))
          let candidate = try #require(
            shader.image(
              identity: identity, terrain: terrain, palette: palette,
              angle: Double(phase) * 0.006, diameter: diameter))
          let lhs = try planetShaderBytes(reference)
          let rhs = try planetShaderBytes(candidate)
          #expect(lhs.count == rhs.count)
          var totalError = 0
          var maximumError = 0
          var maximumAlphaError = 0
          for index in lhs.indices {
            let error = abs(Int(lhs[index]) - Int(rhs[index]))
            totalError += error
            maximumError = max(maximumError, error)
            if index % 4 == 3 { maximumAlphaError = max(maximumAlphaError, error) }
          }
          #expect(maximumError <= 3)
          #expect(Double(totalError) / Double(lhs.count) < 0.1)
          #expect(maximumAlphaError == 0)
          for pixel in [0, diameter - 1, diameter * (diameter - 1), diameter * diameter - 1] {
            #expect((0..<4).allSatisfy { rhs[pixel * 4 + $0] == 0 })
          }
          #expect(rhs[(diameter * (diameter / 2) + diameter / 2) * 4 + 3] == 255)
        }
      }
    }
  }

  @MainActor @Test func identityChangesAndOutputReuseCannotMutatePreviouslyPublishedImages()
    async throws
  {
    let shader = try await Self.makeShader()
    let systems = Universe.galaxy(number: 0)
    let firstIdentity = PlanetIdentity(galaxy: 0, system: systems[7])
    let firstTerrain = PlanetTerrain(identity: firstIdentity)
    let firstPalette = PlanetPalette(identity: firstIdentity)
    let first = try #require(
      shader.image(
        identity: firstIdentity, terrain: firstTerrain, palette: firstPalette, angle: 0,
        diameter: 128))
    let original = try planetShaderBytes(first)
    let secondIdentity = PlanetIdentity(galaxy: 0, system: systems[0])
    let second = try #require(
      shader.image(
        identity: secondIdentity, terrain: PlanetTerrain(identity: secondIdentity),
        palette: PlanetPalette(identity: secondIdentity), angle: 0.222, diameter: 512))
    #expect(second.width == 512 && second.height == 512)
    #expect(try planetShaderBytes(first) == original)
    let repeated = try #require(
      shader.image(
        identity: firstIdentity, terrain: firstTerrain, palette: firstPalette, angle: 0,
        diameter: 128))
    #expect(try planetShaderBytes(repeated) == original)
  }

  @MainActor @Test func productionRendererUsesPreparedGPUWithIndependentReferenceAndCache()
    async throws
  {
    let device = await PlanetRenderer.prepareGPU()
    #expect(device?.isEmpty == false)
    let system = Universe.galaxy(number: 0)[7]
    let preview = PlanetPreview(
      galaxy: 0, system: system, bounds: .init(x: 0, y: 0, width: 257, height: 257), time: 10)
    let image = try #require(PlanetRenderer.image(for: preview, diameter: 257))
    let repeated = try #require(PlanetRenderer.image(for: preview, diameter: 257))
    #expect(image === repeated)
    let reference = try #require(PlanetRenderer.referenceImage(for: preview, diameter: 257))
    #expect(image !== reference)
    #expect(image.colorSpace?.name == CGColorSpace.sRGB)
    #expect(reference.colorSpace?.name == image.colorSpace?.name)
    let lhs = try planetShaderBytes(reference)
    let rhs = try planetShaderBytes(image)
    #expect(zip(lhs, rhs).allSatisfy { abs(Int($0) - Int($1)) <= 3 })
    #expect(PlanetRenderer.image(for: preview, diameter: 769) == nil)
  }

}
