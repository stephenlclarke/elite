import Darwin
import Dispatch
import Foundation

/// Opt-in process-wide allocator observations, never fixture ownership or post-destruction proof.
enum ASANAllocatorDiagnostic {
  enum Method: String, Sendable {
    case livingStation =
      "EliteCoreTests.NativeMissionStationTests/restoringALivingStationUsesTheCurrentCanonicalIdentityWithoutAllocatingOrReusingCustody()"
    case invalidAnchor =
      "EliteCoreTests.NativeMissionStationTests/invalidDecodedAnchorCannotCreateAStationOrMutateAnyNativeState(field:)"
    case deadStation =
      "EliteCoreTests.NativeMissionStationTests/anActualDeadStationCannotBeReplacedByAnOlderLivingReferenceFrame()"
    case staleSalvage =
      "EliteCoreTests.NativeSalvageAuthorityTests/staleHotAuthorityRefusesWorkAndEveryColdFlushWithoutChangingCustody(change:)"
    case catalogueMesh =
      "EliteCoreTests.SalvageCatalogueTests/actualMeshBoundsMaterialsAndFaceWorkGeometryRemainUnnormalized()"

    private static let catalogueArguments = [
      "SH005", "SH006", "SH012", "SH013", "SH014", "SH019", "SH028", "SH034", "SH043",
      "SH045", "SH062", "SH064", "SH066", "SH067", "SH077", "SH078", "SH079", "SH080",
      "SH081", "SH093", "SH096", "SH097", "SH098", "SH099", "SH102", "SH123", "SH127",
      "SH129", "SH132", "SH133", "SH134", "SH141", "SH155", "SH156", "SH161", "SH164",
      "SH171", "SH061",
    ]

    func accepts(_ argument: String) -> Bool {
      switch self {
      case .invalidAnchor: ["player", "unallocated", "visit", "system"].contains(argument)
      case .staleSalvage: ["owner", "hull", "epoch", "actor", "section", "source", "cycle"].contains(argument)
      case .catalogueMesh: argument == "none" || Self.catalogueArguments.contains(argument)
      default: argument == "none"
      }
    }
  }

  enum Phase: String, Sendable {
    case entry, fixtureReady = "fixture-ready", hotWorkReady = "hot-work-ready"
    case preFinalFlush = "pre-final-flush", finalFlushDone = "final-flush-done"
    case bodyExit = "body-exit"
    case profileEntry = "profile-entry", oracleReady = "oracle-ready"
    case cacheBefore = "cache-before", cacheAfter = "cache-after"
    case parityDone = "parity-done", boundsDone = "bounds-done", profilesDone = "profiles-done"
    case textureBefore = "texture-before", textureDone = "texture-done"
    case haflingerBegin = "haflinger-begin", empBefore = "emp-before", empAfter = "emp-after"
    case haflingerDone = "haflinger-done"
  }

  struct Token: Sendable {
    let method: Method
    let argument: String
    let invocation: UInt64

    func checkpoint(_ phase: Phase, argument: String? = nil) {
      guard ASANAllocatorDiagnostic.enabled else { return }
      let boundary = Boundary()
      let tag = method == .catalogueMesh ? (argument ?? self.argument) : self.argument
      _ = State.shared.record(
        method, argument: tag, phase: phase, invocation: invocation, boundary: boundary)
    }

    func catalogueDetail(_ phase: Phase, profile: String) {
      guard method == .catalogueMesh else { return }
      switch profile {
      case "SH005", "SH012", "SH019": checkpoint(phase, argument: profile)
      default: return
      }
    }
  }

  static func begin(_ method: Method, argument: String = "none") -> Token? {
    guard enabled else { return nil }
    let boundary = Boundary()
    guard let invocation = State.shared.record(
      method, argument: argument, phase: .entry, invocation: nil, boundary: boundary)
    else { return nil }
    return Token(method: method, argument: argument, invocation: invocation)
  }

  private static var enabled: Bool {
    guard let value = getenv("ELITE_ASAN_ALLOCATOR_DIAGNOSTIC") else { return false }
    return value[0] == 49 && value[1] == 0
  }

  private struct Boundary {
    let time: UInt64
    let thread: UInt64
    let threadError: Int32
    init() {
      time = DispatchTime.now().uptimeNanoseconds
      var identifier: UInt64 = 0
      threadError = pthread_threadid_np(nil, &identifier)
      thread = identifier
    }
  }

  private struct API {
    typealias Counter = @convention(c) () -> UInt
    typealias Statistics = @convention(c) () -> Void
    let allocated: Counter
    let heap: Counter
    let free: Counter
    let unmapped: Counter
    let statistics: Statistics

    static func resolve() -> Self? {
      #if arch(arm64)
        guard let process = dlopen(nil, RTLD_NOW) else { return nil }
        defer { dlclose(process) }
        guard let allocated = dlsym(process, "__sanitizer_get_current_allocated_bytes"),
          let heap = dlsym(process, "__sanitizer_get_heap_size"),
          let free = dlsym(process, "__sanitizer_get_free_bytes"),
          let unmapped = dlsym(process, "__sanitizer_get_unmapped_bytes"),
          let statistics = dlsym(process, "__asan_print_accumulated_stats")
        else { return nil }
        return Self(
          allocated: unsafeBitCast(allocated, to: Counter.self),
          heap: unsafeBitCast(heap, to: Counter.self), free: unsafeBitCast(free, to: Counter.self),
          unmapped: unsafeBitCast(unmapped, to: Counter.self),
          statistics: unsafeBitCast(statistics, to: Statistics.self))
      #else
        return nil
      #endif
    }
  }

  /// Only finite emission state is shared. No lock extends across a fixture or test body.
  private final class State: @unchecked Sendable {
    static let shared = State()
    private let lock = NSLock()
    private let api = API.resolve()
    private var records = 0
    private var invocations: UInt64 = 0
    private var dumps = 0
    private var stopped = false

    func record(
      _ method: Method, argument: String, phase: Phase, invocation: UInt64?, boundary: Boundary
    ) -> UInt64? {
      lock.lock()
      guard !stopped else { lock.unlock(); return nil }
      if invocation == nil { invocations += 1 }
      let identifier = invocation ?? invocations
      let validArgument = method.accepts(argument)
      let error: String?
      if records == 63 { error = "record-limit" }
      else if !validArgument { error = "invalid-argument" }
      else if boundary.threadError != 0 || boundary.thread == 0 { error = "thread-id-unavailable" }
      else if api == nil { error = "symbols-unavailable" }
      else { error = nil }
      // These getters run sequentially, so the values are not an atomic heap snapshot.
      let values: [UInt]? = error == nil ? api.map {
        [$0.allocated(), $0.heap(), $0.free(), $0.unmapped()]
      } : nil
      let sampled = values == nil ? "null" : String(DispatchTime.now().uptimeNanoseconds)
      let numbers = values?.map { String($0) } ?? Array(repeating: "null", count: 4)
      var dump: Int?
      if error == nil && ((dumps == 0 && phase == .entry)
        || (dumps == 1 && method == .staleSalvage && phase == .hotWorkReady)
        || (dumps == 1 && method == .catalogueMesh && phase == .cacheAfter && argument == "SH005"))
      { dumps += 1; dump = dumps }
      let availability = error == nil ? "available" : "unavailable"
      let errors = error.map { "[\"\($0)\"]" } ?? "[]"
      let tag = validArgument ? argument : "invalid"
      let statistics = dump.map { String($0) } ?? "null"
      let line = "ELITE_ASAN_ALLOCATOR_CHECKPOINT "
        + "{\"schema\":1,\"kind\":\"asan-allocator-checkpoint-v1\",\"time_ns\":\(boundary.time),"
        + "\"sampled_ns\":\(sampled),\"pid\":\(getpid()),\"thread\":\(boundary.thread),"
        + "\"invocation\":\(identifier),\"method\":\"\(method.rawValue)\",\"argument\":\"\(tag)\","
        + "\"phase\":\"\(phase.rawValue)\",\"current_allocated_bytes\":\(numbers[0]),"
        + "\"heap_bytes\":\(numbers[1]),\"free_bytes\":\(numbers[2]),\"unmapped_bytes\":\(numbers[3]),"
        + "\"availability\":\"\(availability)\",\"errors\":\(errors),\"stats_dump\":\(statistics),"
        + "\"sampling\":\"sequential-process-wide\",\"local_destruction_observed\":false}\n"
      records += 1
      let written = line.utf8.count <= 1024 && line.withCString {
        Darwin.write(STDERR_FILENO, $0, line.utf8.count) == line.utf8.count
      }
      if error != nil || !written { stopped = true; dump = nil }
      lock.unlock()
      // The potentially slower public printer never holds our emission lock.
      if dump != nil { api?.statistics() }
      return error == nil && written ? identifier : nil
    }
  }
}
