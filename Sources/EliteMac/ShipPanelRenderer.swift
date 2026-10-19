import AppKit
import EliteCore
import Metal

struct ShipPanelExecution {
  var cpuPanels = 0
  var metalPanels = 0
  var device: String?
  var backendDescription: String {
    guard metalPanels > 0, let device else { return "CPU ship panels" }
    return "Metal ship panels (\(device); \(cpuPanels > 0 ? "mixed CPU" : "all panels"))"
  }
}

struct ShipPanelBudget {
  var runs = 4
  var pixels = 1536 * 1536
}

struct ShipPanelRecord {
  let a: SIMD2<Float>
  let b: SIMD2<Float>
  let c: SIMD2<Float>
  let colour: UInt32
  let padding: UInt32 = 0
}

struct ShipPanelBatch {
  let records: [ShipPanelRecord]
  let bounds: CGRect
  let width: Int
  let height: Int
  let scale: SIMD2<Float>
}

// Metal devices and pipeline states are immutable, thread-safe references. Mutable
// queues, textures and buffers stay on the renderer's main actor.
struct CompiledShipPanelPipeline: @unchecked Sendable {
  let device: any MTLDevice
  let pipeline: any MTLRenderPipelineState
}

/// Startup presentation only. No animation frame or projected geometry is cached.
@MainActor
final class ShipPanelRenderer {
  private let compiler: @Sendable () async throws -> CompiledShipPanelPipeline?
  private var preparation: Task<Void, Never>?
  private var gpu: ShipPanelGPU?
  private(set) var failed = false
  private(set) var failureReason: String?

  init(
    compiler: @escaping @Sendable () async throws -> CompiledShipPanelPipeline? = ShipPanelGPU
      .compile
  ) {
    self.compiler = compiler
  }

  func prepareGPU() async -> String? {
    beginPreparation()
    await preparation?.value
    return gpu?.deviceName
  }

  private func beginPreparation() {
    guard preparation == nil, !failed else { return }
    let compiler = compiler
    preparation = Task { [weak self] in
      do {
        let compiled = try await compiler()
        guard let self else { return }
        if let compiled, let renderer = ShipPanelGPU(compiled: compiled) {
          gpu = renderer
        } else {
          failed = true
          failureReason = "Metal device, eight-sample rendering or queue unavailable"
        }
      } catch {
        self?.failed = true
        self?.failureReason = String(describing: error)
      }
    }
  }

  static func eligible(_ panel: ShipPanel) -> Bool {
    guard panel.vertices.count == 3,
      panel.vertices.allSatisfy({ $0.x.isFinite && $0.y.isFinite })
    else { return false }
    let a = panel.vertices[0]
    let b = panel.vertices[1]
    let c = panel.vertices[2]
    let area = (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
    return area.isFinite && abs(area) > 1e-10
  }

  /// Refusal never draws into the destination. The caller then uses Quartz.
  func draw(
    _ run: ArraySlice<Graphic>, context: CGContext, budget: inout ShipPanelBudget
  ) -> String? {
    guard
      let result = image(
        run, transform: context.ctm, clip: context.boundingBoxOfClipPath, budget: &budget)
    else { return nil }
    context.saveGState()
    context.interpolationQuality = .none
    context.translateBy(x: result.bounds.minX, y: result.bounds.maxY)
    context.scaleBy(x: 1, y: -1)
    context.draw(result.image, in: CGRect(origin: .zero, size: result.bounds.size))
    context.restoreGState()
    return result.device
  }

  func image(
    _ run: ArraySlice<Graphic>, transform: CGAffineTransform, clip: CGRect,
    budget: inout ShipPanelBudget
  ) -> (image: CGImage, bounds: CGRect, device: String)? {
    guard !failed else { return nil }
    guard let gpu else {
      beginPreparation()
      return nil
    }
    guard budget.runs > 0, budget.pixels > 0 else { return nil }
    // Refused attempts also consume a slot, bounding packing work within this frame.
    budget.runs -= 1
    guard
      let batch = Self.batch(run, transform: transform, clip: clip),
      batch.width * batch.height <= budget.pixels
    else { return nil }
    budget.pixels -= batch.width * batch.height
    guard let image = gpu.image(batch) else {
      if gpu.failed {
        failed = true
        self.gpu = nil
      }
      return nil
    }
    return (image, batch.bounds, gpu.deviceName)
  }

  static func batch(
    _ run: ArraySlice<Graphic>, transform: CGAffineTransform, clip: CGRect
  ) -> ShipPanelBatch? {
    guard !run.isEmpty, run.count <= 120_000,
      [transform.a, transform.d, transform.tx, transform.ty].allSatisfy(\.isFinite),
      transform.b == 0, transform.c == 0, transform.a > 0, transform.d != 0,
      clip.origin.x.isFinite, clip.origin.y.isFinite,
      clip.width.isFinite, clip.height.isFinite, !clip.isEmpty
    else { return nil }
    let sx = transform.a
    let sy = abs(transform.d)
    guard (0.0625...16).contains(sx), (0.0625...16).contains(sy) else { return nil }
    var left = Double.infinity
    var top = Double.infinity
    var right = -Double.infinity
    var bottom = -Double.infinity
    for graphic in run {
      guard case .panel(let panel) = graphic, eligible(panel) else { return nil }
      for point in panel.vertices {
        left = min(left, point.x)
        right = max(right, point.x)
        top = min(top, point.y)
        bottom = max(bottom, point.y)
      }
    }
    let logical = CGRect(
      x: left - 0.125 - 1 / sx, y: top - 0.125 - 1 / sy,
      width: right - left + 0.25 + 2 / sx, height: bottom - top + 0.25 + 2 / sy
    ).intersection(clip)
    guard !logical.isNull, !logical.isEmpty else { return nil }
    let device = logical.applying(transform).standardized
    let x0 = floor(device.minX)
    let y0 = floor(device.minY)
    let x1 = ceil(device.maxX)
    let y1 = ceil(device.maxY)
    let width = x1 - x0
    let height = y1 - y0
    guard width.isFinite, height.isFinite, width >= 1, height >= 1,
      width <= 8192, height <= 8192, width * height <= Double(1536 * 1536)
    else { return nil }
    let origin = CGPoint(
      x: (x0 - transform.tx) / sx,
      y: ((transform.d > 0 ? y0 : y1) - transform.ty) / transform.d)
    let bounds = CGRect(x: origin.x, y: origin.y, width: width / sx, height: height / sy)
    var records: [ShipPanelRecord] = []
    records.reserveCapacity(run.count)
    for graphic in run {
      guard case .panel(let panel) = graphic else { return nil }
      func point(_ vertex: ScreenPoint) -> SIMD2<Float>? {
        let x = vertex.x - origin.x
        let y = vertex.y - origin.y
        let converted = SIMD2<Float>(Float(x), Float(y))
        guard abs(x) <= 65536, abs(y) <= 65536,
          converted.x.isFinite, converted.y.isFinite,
          abs(Double(converted.x) - x) * sx < 0.0001,
          abs(Double(converted.y) - y) * sy < 0.0001
        else { return nil }
        return converted
      }
      guard let a = point(panel.vertices[0]), let b = point(panel.vertices[1]),
        let c = point(panel.vertices[2])
      else { return nil }
      let area = (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
      guard area.isFinite, area != 0 else { return nil }
      records.append(.init(a: a, b: b, c: c, colour: panel.colour))
    }
    return .init(
      records: records, bounds: bounds, width: Int(width), height: Int(height),
      scale: SIMD2(Float(sx), Float(sy)))
  }
}

@MainActor
private final class ShipPanelGPU {
  private let compiled: CompiledShipPanelPipeline
  private let queue: any MTLCommandQueue
  private let colourSpace: CGColorSpace
  private var multisample: (any MTLTexture)?
  private var resolved: (any MTLTexture)?
  private var output: (any MTLBuffer)?
  private var vertices: (any MTLBuffer)?
  private var samplePositions: [SIMD2<Float>]
  private(set) var failed = false
  var deviceName: String { compiled.device.name }

  init?(compiled: CompiledShipPanelPipeline) {
    guard let queue = compiled.device.makeCommandQueue(),
      let colourSpace = CGColor(red: 0, green: 0, blue: 0, alpha: 1).colorSpace
    else { return nil }
    self.compiled = compiled
    self.queue = queue
    self.colourSpace = colourSpace
    let positions = compiled.device.getDefaultSamplePositions(sampleCount: 8)
    samplePositions = positions.map { SIMD2($0.x, $0.y) }
  }

  nonisolated static func compile() async throws -> CompiledShipPanelPipeline? {
    try await Task.detached(priority: .utility) { () throws -> CompiledShipPanelPipeline? in
      guard let device = MTLCreateSystemDefaultDevice(), device.supportsTextureSampleCount(8)
      else { return nil }
      let options = MTLCompileOptions()
      options.fastMathEnabled = false
      let library = try device.makeLibrary(source: shader, options: options)
      let descriptor = MTLRenderPipelineDescriptor()
      descriptor.vertexFunction = library.makeFunction(name: "shipPanelVertex")
      descriptor.fragmentFunction = library.makeFunction(name: "shipPanelFragment")
      descriptor.rasterSampleCount = 8
      descriptor.colorAttachments[0].pixelFormat = .rgba8Unorm
      return .init(
        device: device, pipeline: try device.makeRenderPipelineState(descriptor: descriptor))
    }.value
  }

  func image(_ batch: ShipPanelBatch) -> CGImage? {
    let rowBytes = (batch.width * 4 + 255) / 256 * 256
    let byteCount = rowBytes * batch.height
    let vertexBytes = batch.records.count * MemoryLayout<ShipPanelRecord>.stride
    guard MemoryLayout<ShipPanelRecord>.stride == 32,
      byteCount <= compiled.device.maxBufferLength, vertexBytes <= compiled.device.maxBufferLength
    else { return nil }
    if resolved?.width != batch.width || resolved?.height != batch.height {
      let descriptor = MTLTextureDescriptor.texture2DDescriptor(
        pixelFormat: .rgba8Unorm, width: batch.width, height: batch.height, mipmapped: false)
      descriptor.storageMode = .private
      descriptor.usage = .renderTarget
      resolved = compiled.device.makeTexture(descriptor: descriptor)
      descriptor.textureType = .type2DMultisample
      descriptor.sampleCount = 8
      multisample = compiled.device.makeTexture(descriptor: descriptor)
      output = compiled.device.makeBuffer(length: byteCount, options: .storageModeShared)
    }
    if vertices == nil || vertices!.length < vertexBytes {
      vertices = compiled.device.makeBuffer(length: vertexBytes, options: .storageModeShared)
    }
    guard let resolved, let multisample, let output, let vertices,
      let command = queue.makeCommandBuffer()
    else {
      failed = true
      return nil
    }
    batch.records.withUnsafeBytes { bytes in
      if let base = bytes.baseAddress {
        vertices.contents().copyMemory(from: base, byteCount: bytes.count)
      }
    }
    let pass = MTLRenderPassDescriptor()
    pass.colorAttachments[0].texture = multisample
    pass.colorAttachments[0].resolveTexture = resolved
    pass.colorAttachments[0].loadAction = .clear
    pass.colorAttachments[0].storeAction = .multisampleResolve
    pass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0)
    guard let encoder = command.makeRenderCommandEncoder(descriptor: pass)
    else {
      failed = true
      return nil
    }
    encoder.setRenderPipelineState(compiled.pipeline)
    encoder.setCullMode(.none)
    encoder.setVertexBuffer(vertices, offset: 0, index: 0)
    encoder.setFragmentBuffer(vertices, offset: 0, index: 0)
    var dimensions = SIMD4<Float>(
      Float(batch.width), Float(batch.height), batch.scale.x, batch.scale.y)
    encoder.setVertexBytes(&dimensions, length: MemoryLayout<SIMD4<Float>>.stride, index: 1)
    encoder.setFragmentBytes(&dimensions, length: MemoryLayout<SIMD4<Float>>.stride, index: 1)
    samplePositions.withUnsafeBytes { bytes in
      if let base = bytes.baseAddress {
        encoder.setFragmentBytes(base, length: bytes.count, index: 2)
      }
    }
    encoder.drawPrimitives(
      type: .triangle, vertexStart: 0, vertexCount: 6, instanceCount: batch.records.count)
    encoder.endEncoding()
    guard let blit = command.makeBlitCommandEncoder() else {
      failed = true
      return nil
    }
    blit.copy(
      from: resolved, sourceSlice: 0, sourceLevel: 0, sourceOrigin: .init(x: 0, y: 0, z: 0),
      sourceSize: .init(width: batch.width, height: batch.height, depth: 1),
      to: output, destinationOffset: 0, destinationBytesPerRow: rowBytes,
      destinationBytesPerImage: byteCount)
    blit.endEncoding()
    command.commit()
    command.waitUntilCompleted()
    guard command.status == .completed, command.error == nil else {
      failed = true
      return nil
    }
    // A published image owns copied bytes, independent of the next GPU submission.
    let data = Data(bytes: output.contents(), count: byteCount) as CFData
    guard let provider = CGDataProvider(data: data) else { return nil }
    return CGImage(
      width: batch.width, height: batch.height, bitsPerComponent: 8, bitsPerPixel: 32,
      bytesPerRow: rowBytes, space: colourSpace,
      bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
      provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
  }

  nonisolated private static let shader = """
    #include <metal_stdlib>
    using namespace metal;
    struct Panel { float2 a; float2 b; float2 c; uint colour; uint padding; };
    struct Vertex { float4 position [[position]]; uint panel [[flat]]; };
    struct Fragment { float4 colour [[color(0)]]; uint mask [[sample_mask]]; };
    vertex Vertex shipPanelVertex(uint vertexIndex [[vertex_id]], uint instance [[instance_id]],
      device const Panel *panels [[buffer(0)]], constant float4 &size [[buffer(1)]]) {
      const float2 corners[6] = {float2(0,0),float2(1,0),float2(0,1),
                                float2(0,1),float2(1,0),float2(1,1)};
      Panel p = panels[instance];
      float2 lo = min(p.a,min(p.b,p.c))*size.zw - 0.125f*size.zw - 1.0f;
      float2 hi = max(p.a,max(p.b,p.c))*size.zw + 0.125f*size.zw + 1.0f;
      float2 pixel = mix(lo,hi,corners[vertexIndex]);
      Vertex result;
      result.position = float4(pixel.x*2.0f/size.x-1.0f,1.0f-pixel.y*2.0f/size.y,0,1);
      result.panel = instance;
      return result;
    }
    float cross2(float2 a,float2 b) { return a.x*b.y-a.y*b.x; }
    float distance2(float2 p,float2 a,float2 b) {
      float2 edge=b-a;
      float t=clamp(dot(p-a,edge)/dot(edge,edge),0.0f,1.0f);
      float2 d=p-a-t*edge;
      return dot(d,d);
    }
    fragment Fragment shipPanelFragment(Vertex in [[stage_in]],
      device const Panel *panels [[buffer(0)]], constant float4 &size [[buffer(1)]],
      constant float2 *samples [[buffer(2)]]) {
      Panel p=panels[in.panel];
      uint mask=0;
      for (uint i=0;i<8;i++) {
        float2 q=(floor(in.position.xy)+samples[i])/size.zw;
        float a=cross2(p.b-p.a,q-p.a), b=cross2(p.c-p.b,q-p.b), c=cross2(p.a-p.c,q-p.c);
        bool inside=(a>=0&&b>=0&&c>=0)||(a<=0&&b<=0&&c<=0);
        float edge=min(distance2(q,p.a,p.b),min(distance2(q,p.b,p.c),distance2(q,p.c,p.a)));
        if (inside||edge<=0.015625f) mask|=1u<<i;
      }
      // Never write the transparent part of an instance over earlier panels.
      if (mask==0) discard_fragment();
      Fragment result;
      result.colour=float4(float((p.colour>>24)&255),float((p.colour>>16)&255),
                           float((p.colour>>8)&255),255.0f)/255.0f;
      result.mask=mask;
      return result;
    }
    """
}
