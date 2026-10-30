import CoreGraphics
import Foundation
import L337Core
import Metal

enum PlanetGPUUniform: Int, CaseIterable, Sendable {
  case diameter, angle, oceanR, oceanG, oceanB, landR, landG, landB, ice, seaLevel, highlandR,
    highlandG, highlandB, vegetationR, vegetationG, vegetationB, cloudR, cloudG, cloudB, cloudLow,
    cloudHigh, cloudOpacity, vegetationStrength, highlandStrength, atmosphereR, atmosphereG,
    atmosphereB, atmosphereStrength, surfaceHaze, rimWidth, rimOpacity, sunX, sunY, sunZ,
    sunStrength, nightR, nightG, nightB, nightIntensity, nightScatter
}

/// Metal devices and compiled pipeline states support concurrent use. These two
/// immutable references cross actors; command queues and mutable buffers do not.
struct CompiledPlanetPipeline: @unchecked Sendable {
  fileprivate let device: any MTLDevice
  fileprivate let pipeline: any MTLComputePipelineState
  var deviceName: String { device.name }
}

/// Presentation-only GPU shading; all mutable resources remain on the main actor.
@MainActor
final class PlanetGPUShader {
  private let compiled: CompiledPlanetPipeline
  private let queue: (any MTLCommandQueue)?
  private let colourSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
  private var output: (any MTLBuffer)?
  private var terrainIdentity: PlanetIdentity?
  private var elevation: (any MTLBuffer)?
  private var clouds: (any MTLBuffer)?
  private var settlementKey: PlanetSettlementKey?
  private var settlementEmission: (any MTLBuffer)?
  private var settlementScatter: (any MTLBuffer)?
  var deviceName: String { compiled.deviceName }

  init(pipeline: CompiledPlanetPipeline) {
    compiled = pipeline
    queue = pipeline.device.makeCommandQueue()
  }

  /// Compile without blocking a first draw. The caller owns a single preparation
  /// task and continues using the CPU renderer until this immutable result exists.
  nonisolated static func compile() async -> CompiledPlanetPipeline? {
    await Task.detached(priority: .utility) {
      guard let device = MTLCreateSystemDefaultDevice() else { return nil }
      do {
        let options = MTLCompileOptions()
        options.fastMathEnabled = false
        let library = try device.makeLibrary(source: shader, options: options)
        guard let function = library.makeFunction(name: "planetImage") else { return nil }
        let pipeline = try device.makeComputePipelineState(function: function)
        return CompiledPlanetPipeline(device: device, pipeline: pipeline)
      } catch {
        return nil
      }
    }.value
  }

  /// Angle is already quantized by the caller to the CPU renderer's 0.006 phase.
  /// Return nil for CPU fallback; never publish shared output storage as an image.
  func image(
    identity: PlanetIdentity, terrain: PlanetTerrain, palette: PlanetPalette,
    angle: Double, diameter: Int, lighting: PlanetLighting = .presentation,
    night: PlanetNightProfile = .uninhabited, settlements: PlanetSettlementMask = .empty
  ) -> CGImage? {
    guard (32...768).contains(diameter), angle.isFinite, Float(angle).isFinite,
      terrain.elevation.count == PlanetTerrain.width * PlanetTerrain.height,
      terrain.clouds.count == PlanetTerrain.width * PlanetTerrain.height,
      settlements.key.map({
        $0.identity == identity && $0.seaLevel == palette.seaLevel && $0.ice == palette.ice
          && $0.coverage == night.settlementCoverage
      }) ?? (night.emissionIntensity == 0),
      let queue, prepareTerrain(identity: identity, terrain: terrain),
      prepareSettlements(settlements)
    else { return nil }
    if output == nil {
      output = compiled.device.makeBuffer(length: 768 * 768 * 4, options: .storageModeShared)
    }
    guard let output, let elevation, let clouds, let settlementEmission, let settlementScatter,
      let command = queue.makeCommandBuffer(), let encoder = command.makeComputeCommandEncoder()
    else { return nil }
    let uniforms = Self.uniformValues(
      palette: palette, angle: angle, diameter: diameter, lighting: lighting, night: night)
    encoder.setComputePipelineState(compiled.pipeline)
    encoder.setBuffer(elevation, offset: 0, index: 0)
    encoder.setBuffer(clouds, offset: 0, index: 1)
    encoder.setBuffer(output, offset: 0, index: 2)
    encoder.setBuffer(settlementEmission, offset: 0, index: 4)
    encoder.setBuffer(settlementScatter, offset: 0, index: 5)
    uniforms.withUnsafeBytes { encoder.setBytes($0.baseAddress!, length: $0.count, index: 3) }
    let width = compiled.pipeline.threadExecutionWidth
    let height = min(8, compiled.pipeline.maxTotalThreadsPerThreadgroup / width)
    encoder.dispatchThreads(
      .init(width: diameter, height: diameter, depth: 1),
      threadsPerThreadgroup: .init(width: width, height: height, depth: 1))
    encoder.endEncoding()
    command.commit()
    command.waitUntilCompleted()
    guard command.status == .completed, command.error == nil else { return nil }
    // The provider retains its own bytes; later GPU writes cannot mutate old frames.
    let data = Data(bytes: output.contents(), count: diameter * diameter * 4) as CFData
    guard let provider = CGDataProvider(data: data) else { return nil }
    return CGImage(
      width: diameter, height: diameter, bitsPerComponent: 8, bitsPerPixel: 32,
      bytesPerRow: diameter * 4, space: colourSpace,
      bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
      provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
  }

  /// Named slots are shared with the compiled shader source below.
  static func uniformValues(
    palette: PlanetPalette, angle: Double, diameter: Int, lighting: PlanetLighting = .presentation,
    night: PlanetNightProfile = .uninhabited
  ) -> [Float] {
    var values = [Float](repeating: 0, count: PlanetGPUUniform.allCases.count)
    values[PlanetGPUUniform.diameter.rawValue] = Float(diameter)
    values[PlanetGPUUniform.angle.rawValue] = Float(angle)
    values[PlanetGPUUniform.oceanR.rawValue] = Float(palette.ocean.x)
    values[PlanetGPUUniform.oceanG.rawValue] = Float(palette.ocean.y)
    values[PlanetGPUUniform.oceanB.rawValue] = Float(palette.ocean.z)
    values[PlanetGPUUniform.landR.rawValue] = Float(palette.land.x)
    values[PlanetGPUUniform.landG.rawValue] = Float(palette.land.y)
    values[PlanetGPUUniform.landB.rawValue] = Float(palette.land.z)
    values[PlanetGPUUniform.ice.rawValue] = Float(palette.ice)
    values[PlanetGPUUniform.seaLevel.rawValue] = Float(palette.seaLevel)
    values[PlanetGPUUniform.highlandR.rawValue] = Float(palette.profile.highland.x)
    values[PlanetGPUUniform.highlandG.rawValue] = Float(palette.profile.highland.y)
    values[PlanetGPUUniform.highlandB.rawValue] = Float(palette.profile.highland.z)
    values[PlanetGPUUniform.vegetationR.rawValue] = Float(palette.profile.vegetation.x)
    values[PlanetGPUUniform.vegetationG.rawValue] = Float(palette.profile.vegetation.y)
    values[PlanetGPUUniform.vegetationB.rawValue] = Float(palette.profile.vegetation.z)
    values[PlanetGPUUniform.cloudR.rawValue] = Float(palette.profile.cloudColour.x)
    values[PlanetGPUUniform.cloudG.rawValue] = Float(palette.profile.cloudColour.y)
    values[PlanetGPUUniform.cloudB.rawValue] = Float(palette.profile.cloudColour.z)
    values[PlanetGPUUniform.cloudLow.rawValue] = Float(palette.profile.cloudLow)
    values[PlanetGPUUniform.cloudHigh.rawValue] = Float(palette.profile.cloudHigh)
    values[PlanetGPUUniform.cloudOpacity.rawValue] = Float(palette.profile.cloudOpacity)
    values[PlanetGPUUniform.vegetationStrength.rawValue] = Float(palette.profile.vegetationStrength)
    values[PlanetGPUUniform.highlandStrength.rawValue] = Float(palette.profile.highlandStrength)
    values[PlanetGPUUniform.atmosphereR.rawValue] = Float(palette.profile.atmosphereColour.x)
    values[PlanetGPUUniform.atmosphereG.rawValue] = Float(palette.profile.atmosphereColour.y)
    values[PlanetGPUUniform.atmosphereB.rawValue] = Float(palette.profile.atmosphereColour.z)
    values[PlanetGPUUniform.atmosphereStrength.rawValue] = Float(palette.profile.atmosphereStrength)
    values[PlanetGPUUniform.surfaceHaze.rawValue] = Float(palette.profile.surfaceHaze)
    values[PlanetGPUUniform.rimWidth.rawValue] = Float(palette.profile.rimWidth)
    values[PlanetGPUUniform.rimOpacity.rawValue] = Float(palette.profile.rimOpacity)
    values[PlanetGPUUniform.sunX.rawValue] = Float(lighting.direction.x)
    values[PlanetGPUUniform.sunY.rawValue] = Float(lighting.direction.y)
    values[PlanetGPUUniform.sunZ.rawValue] = Float(lighting.direction.z)
    values[PlanetGPUUniform.sunStrength.rawValue] = Float(lighting.strength)
    values[PlanetGPUUniform.nightR.rawValue] = Float(night.colour.x)
    values[PlanetGPUUniform.nightG.rawValue] = Float(night.colour.y)
    values[PlanetGPUUniform.nightB.rawValue] = Float(night.colour.z)
    values[PlanetGPUUniform.nightIntensity.rawValue] = Float(night.emissionIntensity)
    values[PlanetGPUUniform.nightScatter.rawValue] = Float(night.smogScatter)
    return values
  }

  private func prepareSettlements(_ mask: PlanetSettlementMask) -> Bool {
    guard mask.emission.count == PlanetTerrain.width * PlanetTerrain.height,
      mask.scatter.count == mask.emission.count
    else { return false }
    if settlementKey == mask.key, settlementEmission != nil, settlementScatter != nil {
      return true
    }
    let device = compiled.device
    guard
      let emission = mask.emission.withUnsafeBytes({ bytes in
        device.makeBuffer(
          bytes: bytes.baseAddress!, length: bytes.count, options: .storageModeShared)
      }),
      let scatter = mask.scatter.withUnsafeBytes({ bytes in
        device.makeBuffer(
          bytes: bytes.baseAddress!, length: bytes.count, options: .storageModeShared)
      })
    else { return false }
    settlementEmission = emission
    settlementScatter = scatter
    settlementKey = mask.key
    return true
  }

  private func prepareTerrain(identity: PlanetIdentity, terrain: PlanetTerrain) -> Bool {
    if terrainIdentity == identity, elevation != nil, clouds != nil { return true }
    let device = compiled.device
    guard
      let nextElevation = terrain.elevation.withUnsafeBytes({ bytes in
        device.makeBuffer(
          bytes: bytes.baseAddress!, length: bytes.count, options: .storageModeShared)
      }),
      let nextClouds = terrain.clouds.withUnsafeBytes({ bytes in
        device.makeBuffer(
          bytes: bytes.baseAddress!, length: bytes.count, options: .storageModeShared)
      })
    else { return false }
    elevation = nextElevation
    clouds = nextClouds
    terrainIdentity = identity
    return true
  }

  nonisolated private static let shader = """
    #include <metal_stdlib>
    using namespace metal;

    float terrainSample(device const float* values, float longitude, float latitude) {
      const float pi = 3.14159265358979323846f;
      float u = fmod(longitude / (2.0f * pi) + 0.5f, 1.0f);
      if (u < 0.0f) u += 1.0f;
      float x = u * 256.0f;
      float y = clamp((0.5f - latitude / pi) * 127.0f, 0.0f, 127.0f);
      uint ix = uint(x), iy = uint(y);
      uint nextX = (ix + 1) % 256, nextY = min(iy + 1, 127u);
      float tx = x - float(ix), ty = y - float(iy);
      float a = values[iy * 256 + ix];
      float b = values[iy * 256 + nextX];
      float c = values[nextY * 256 + ix];
      float d = values[nextY * 256 + nextX];
      float top = a + (b - a) * tx;
      float bottom = c + (d - c) * tx;
      return top + (bottom - top) * ty;
    }

    float smoothValue(float low, float high, float value) {
      float t = clamp((value - low) / (high - low), 0.0f, 1.0f);
      return t * t * (3.0f - 2.0f * t);
    }

    float3 blendValue(float3 a, float3 b, float t) { return a + (b - a) * t; }

    kernel void planetImage(device const float* elevation [[buffer(0)]],
                            device const float* clouds [[buffer(1)]],
                            device uchar4* output [[buffer(2)]],
                            constant float* u [[buffer(3)]],
                            device const float* settlements [[buffer(4)]],
                            device const float* scatter [[buffer(5)]],
                            uint2 gid [[thread_position_in_grid]]) {
      uint diameter = uint(u[\(PlanetGPUUniform.diameter.rawValue)]);
      if (gid.x >= diameter || gid.y >= diameter) return;
      float nx = (float(gid.x) + 0.5f - float(diameter) / 2.0f) / (float(diameter) * 0.47f);
      float ny = (float(diameter) / 2.0f - float(gid.y) - 0.5f) / (float(diameter) * 0.47f);
      float radius = nx * nx + ny * ny;
      float haze = max(0.0f, 1.0f - (sqrt(radius) - 1.0f) / u[\(PlanetGPUUniform.rimWidth.rawValue)]);
      float alpha = radius < 1.0f ? 1.0f : haze * haze * u[\(PlanetGPUUniform.rimOpacity.rawValue)];
      float3 colour;
      if (radius >= 1.0f) {
        float sunlight = nx * u[\(PlanetGPUUniform.sunX.rawValue)] + ny * u[\(PlanetGPUUniform.sunY.rawValue)];
        float rimLight = 0.04f + 0.96f * smoothValue(-0.12f, 0.30f, sunlight) * u[\(PlanetGPUUniform.sunStrength.rawValue)];
        colour = float3(u[\(PlanetGPUUniform.atmosphereR.rawValue)], u[\(PlanetGPUUniform.atmosphereG.rawValue)], u[\(PlanetGPUUniform.atmosphereB.rawValue)]) * alpha * rimLight;
      } else {
        float angle = u[\(PlanetGPUUniform.angle.rawValue)];
        float3 ocean = float3(u[\(PlanetGPUUniform.oceanR.rawValue)], u[\(PlanetGPUUniform.oceanG.rawValue)], u[\(PlanetGPUUniform.oceanB.rawValue)]);
        float3 landColour = float3(u[\(PlanetGPUUniform.landR.rawValue)], u[\(PlanetGPUUniform.landG.rawValue)], u[\(PlanetGPUUniform.landB.rawValue)]);
        float nz = sqrt(1.0f - radius);
        float latitude = asin(ny);
        float longitude = atan2(nx, nz) + angle;
        float height = terrainSample(elevation, longitude, latitude);
        float cloud = terrainSample(clouds, longitude + angle * 0.08f, latitude);
        float coast = smoothValue(u[\(PlanetGPUUniform.seaLevel.rawValue)] - 0.018f, u[\(PlanetGPUUniform.seaLevel.rawValue)] + 0.018f, height);
        float highland = smoothValue(u[\(PlanetGPUUniform.seaLevel.rawValue)] + 0.04f, 0.8f, height);
        float3 land = blendValue(landColour, float3(u[\(PlanetGPUUniform.highlandR.rawValue)], u[\(PlanetGPUUniform.highlandG.rawValue)], u[\(PlanetGPUUniform.highlandB.rawValue)]), highland * u[\(PlanetGPUUniform.highlandStrength.rawValue)]);
        float vegetation = smoothValue(u[\(PlanetGPUUniform.seaLevel.rawValue)] + 0.015f, u[\(PlanetGPUUniform.seaLevel.rawValue)] + 0.13f, height)
          * (1.0f - highland) * u[\(PlanetGPUUniform.vegetationStrength.rawValue)];
        land = blendValue(land, float3(u[\(PlanetGPUUniform.vegetationR.rawValue)], u[\(PlanetGPUUniform.vegetationG.rawValue)], u[\(PlanetGPUUniform.vegetationB.rawValue)]), vegetation);
        float3 surface = blendValue(ocean, land, coast);
        float ice = smoothValue(u[\(PlanetGPUUniform.ice.rawValue)] - 0.06f, u[\(PlanetGPUUniform.ice.rawValue)] + 0.02f, abs(ny));
        surface = blendValue(surface, float3(0.81f, 0.89f, 0.93f), ice);
        float cloudOpacity = smoothValue(u[\(PlanetGPUUniform.cloudLow.rawValue)], u[\(PlanetGPUUniform.cloudHigh.rawValue)], cloud) * u[\(PlanetGPUUniform.cloudOpacity.rawValue)];
        surface = blendValue(surface, float3(u[\(PlanetGPUUniform.cloudR.rawValue)], u[\(PlanetGPUUniform.cloudG.rawValue)], u[\(PlanetGPUUniform.cloudB.rawValue)]), cloudOpacity);
        surface = blendValue(surface, float3(u[\(PlanetGPUUniform.atmosphereR.rawValue)], u[\(PlanetGPUUniform.atmosphereG.rawValue)], u[\(PlanetGPUUniform.atmosphereB.rawValue)]), u[\(PlanetGPUUniform.surfaceHaze.rawValue)]);
        float sunlight = nx * u[\(PlanetGPUUniform.sunX.rawValue)] + ny * u[\(PlanetGPUUniform.sunY.rawValue)] + nz * u[\(PlanetGPUUniform.sunZ.rawValue)];
        float illumination = 0.006f + 0.994f * smoothValue(-0.08f, 0.80f, sunlight) * u[\(PlanetGPUUniform.sunStrength.rawValue)];
        float atmosphere = pow(1.0f - nz, 3.0f) * smoothValue(-0.12f, 0.50f, sunlight)
          * u[\(PlanetGPUUniform.atmosphereStrength.rawValue)] * u[\(PlanetGPUUniform.sunStrength.rawValue)];
        float dark = 1.0f - smoothValue(-0.12f, 0.08f, sunlight) * u[\(PlanetGPUUniform.sunStrength.rawValue)];
        float emission = 0.0f;
        if (dark > 0.0f && u[\(PlanetGPUUniform.nightIntensity.rawValue)] > 0.0f) {
          float cities = terrainSample(settlements, longitude, latitude);
          float localScatter = terrainSample(scatter, longitude, latitude);
          emission = cities * (1.0f - cloudOpacity * 0.85f)
            + localScatter * u[\(PlanetGPUUniform.nightScatter.rawValue)] * (0.15f + cloudOpacity * 0.85f);
        }
        colour = surface * illumination + float3(u[\(PlanetGPUUniform.atmosphereR.rawValue)], u[\(PlanetGPUUniform.atmosphereG.rawValue)], u[\(PlanetGPUUniform.atmosphereB.rawValue)]) * atmosphere
          + float3(u[\(PlanetGPUUniform.nightR.rawValue)], u[\(PlanetGPUUniform.nightG.rawValue)], u[\(PlanetGPUUniform.nightB.rawValue)]) * (emission * u[\(PlanetGPUUniform.nightIntensity.rawValue)] * dark);
      }
      output[gid.y * diameter + gid.x] = uchar4(clamp(float4(colour, alpha) * 255.0f, 0.0f, 255.0f));
    }
    """
}
