import CoreGraphics
import EliteCore
import Foundation
import Metal

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
    angle: Double, diameter: Int
  ) -> CGImage? {
    guard (32...768).contains(diameter), angle.isFinite, Float(angle).isFinite,
      terrain.elevation.count == PlanetTerrain.width * PlanetTerrain.height,
      terrain.clouds.count == PlanetTerrain.width * PlanetTerrain.height,
      let queue, prepareTerrain(identity: identity, terrain: terrain)
    else { return nil }
    if output == nil {
      output = compiled.device.makeBuffer(length: 768 * 768 * 4, options: .storageModeShared)
    }
    guard let output, let elevation, let clouds,
      let command = queue.makeCommandBuffer(), let encoder = command.makeComputeCommandEncoder()
    else { return nil }
    let uniforms: [Float] = [
      Float(diameter), Float(angle),
      Float(palette.ocean.x), Float(palette.ocean.y), Float(palette.ocean.z),
      Float(palette.land.x), Float(palette.land.y), Float(palette.land.z),
      Float(palette.ice), Float(palette.seaLevel),
    ]
    encoder.setComputePipelineState(compiled.pipeline)
    encoder.setBuffer(elevation, offset: 0, index: 0)
    encoder.setBuffer(clouds, offset: 0, index: 1)
    encoder.setBuffer(output, offset: 0, index: 2)
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
                            uint2 gid [[thread_position_in_grid]]) {
      uint diameter = uint(u[0]);
      if (gid.x >= diameter || gid.y >= diameter) return;
      float nx = (float(gid.x) + 0.5f - float(diameter) / 2.0f) / (float(diameter) * 0.47f);
      float ny = (float(diameter) / 2.0f - float(gid.y) - 0.5f) / (float(diameter) * 0.47f);
      float radius = nx * nx + ny * ny;
      float haze = max(0.0f, 1.0f - (sqrt(radius) - 1.0f) / 0.035f);
      float alpha = radius < 1.0f ? 1.0f : haze * haze * 0.25f;
      float3 colour;
      if (radius >= 1.0f) {
        colour = float3(0.12f, 0.35f, 0.66f) * alpha;
      } else {
        float angle = u[1];
        float3 ocean = float3(u[2], u[3], u[4]);
        float3 landColour = float3(u[5], u[6], u[7]);
        float nz = sqrt(1.0f - radius);
        float latitude = asin(ny);
        float longitude = atan2(nx, nz) + angle;
        float height = terrainSample(elevation, longitude, latitude);
        float cloud = terrainSample(clouds, longitude + angle * 0.08f, latitude);
        float coast = smoothValue(u[9] - 0.018f, u[9] + 0.018f, height);
        float highland = smoothValue(u[9] + 0.04f, 0.8f, height);
        float3 land = blendValue(landColour, float3(0.56f, 0.46f, 0.30f), highland * 0.65f);
        float3 surface = blendValue(ocean, land, coast);
        float ice = smoothValue(u[8] - 0.06f, u[8] + 0.02f, abs(ny));
        surface = blendValue(surface, float3(0.81f, 0.89f, 0.93f), ice);
        float cloudOpacity = smoothValue(0.50f, 0.67f, cloud) * 0.80f;
        surface = blendValue(surface, float3(0.92f, 0.95f, 1.0f), cloudOpacity);
        float sunlight = -nx * 0.52f + ny * 0.35f + nz * 0.78f;
        float illumination = 0.035f + 0.965f * smoothValue(-0.10f, 0.80f, sunlight);
        float atmosphere = pow(1.0f - nz, 3.0f) * smoothValue(-0.12f, 0.50f, sunlight) * 0.40f;
        colour = surface * illumination + float3(0.20f, 0.49f, 0.85f) * atmosphere;
      }
      output[gid.y * diameter + gid.x] = uchar4(clamp(float4(colour, alpha) * 255.0f, 0.0f, 255.0f));
    }
    """
}
