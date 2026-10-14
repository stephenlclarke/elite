import Foundation

public struct ContractStationIdentity: Codable, Sendable, Equatable {
  public let galaxy: Int
  public let system: Int
  public let stationClass: String
  public var key: String { "\(stationClass):\(galaxy):\(system)" }
  var valid: Bool {
    (0..<8).contains(galaxy) && (0...256).contains(system) && stationClass == "main-orbital"
  }
}
public struct ScriptBoardDefinition: Codable, Sendable {
  public let id: String
  public let title: String
  public let generator: String
  public let clock: ScriptClockDomain
  public let refreshSeconds: Double?
  public let exclusiveGroup: String?
  var period: Double { refreshSeconds ?? 3600 }
  var valid: Bool {
    PackValidation.localID(id) && (1...160).contains(title.count)
      && generator.range(of: "^[A-Za-z_][A-Za-z0-9_]{0,79}$", options: .regularExpression) != nil
      && period.isFinite && (1...1e9).contains(period)
      && (exclusiveGroup.map(PackValidation.localID) ?? true)
  }
}
public enum ContractOfferStatus: Codable, Sendable, Equatable {
  case available, declined
  case accepted(UUID)
}
public struct ScriptContractOffer: Codable, Sendable, Equatable, Identifiable {
  public let id: UUID
  public let key: String
  public let title: String
  public let briefing: String
  public let destinationGalaxy: Int
  public let destinationSystem: Int
  public let reward: Int
  public let deposit: Int
  public let failureReward: Int
  public let refundOnFailure: Bool
  public let duration: Double
  public let parameters: ScriptValue
  public var status: ContractOfferStatus = .available
  var valid: Bool {
    PackValidation.localID(key) && (1...160).contains(title.count)
      && (1...12000).contains(briefing.utf8.count)
      && (0..<8).contains(destinationGalaxy) && (0...255).contains(destinationSystem)
      && [reward, deposit, failureReward].allSatisfy { (0...4_294_967_295).contains($0) }
      && reward <= 4_294_967_295 - deposit
      && failureReward <= 4_294_967_295 - (refundOnFailure ? deposit : 0)
      && duration.isFinite && (0...1e9).contains(duration)
      && parameters.object != nil && (try? ScriptWire.encode([parameters], limit: 4096)) != nil
  }
}
public struct ScriptContractBoard: Codable, Sendable, Equatable {
  public let id: String
  public let provider: String
  public let version: String
  public let digest: String
  public let title: String
  public let station: ContractStationIdentity
  public let revision: Int64
  public let seed: UInt64
  public let clock: ScriptClockDomain
  public let period: Double
  public let group: String
  public var offers: [ScriptContractOffer]
  public var cacheKey: String { digest + "/" + id + "/" + station.key }
  var valid: Bool {
    PackValidation.identifier(provider) && PackValidation.version(version)
      && digest.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil
      && PackValidation.localID(id) && station.valid && (1...160).contains(title.count)
      && revision >= 0 && revision <= 1_000_000_000_000 && period.isFinite
      && (1...1e9).contains(period)
      && group == provider + "/" + String(group.split(separator: "/").last ?? "")
      && PackValidation.localID(String(group.split(separator: "/").last ?? ""))
      && (clock == .local || clock == .flight)
      && offers.count <= 16 && Set(offers.map(\.id)).count == offers.count
      && Set(offers.map(\.key)).count == offers.count && offers.allSatisfy(\.valid)
  }
}
public struct ScriptContractJob: Codable, Sendable, Equatable {
  public let boardKey: String
  public let provider: String
  public let version: String
  public let digest: String
  public let station: ContractStationIdentity
  public let boardRevision: Int64
  public let group: String
  public let offer: ScriptContractOffer
  public let clock: ScriptClockDomain
  public let acceptedAt: Double
  public let deadline: Double?
  public var settled = false
  public var settlementOutcome: ScriptOutcome?
  public var settlementAmount: Int?
  public var settledAt: Double?
  var valid: Bool {
    let path = boardKey.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
    let groupParts = group.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
    guard offer.valid, path.count == 3, path[0] == digest, PackValidation.localID(path[1]),
      path[2] == station.key,
      groupParts.count == 2, groupParts[0] == provider, PackValidation.localID(groupParts[1])
    else { return false }
    let expectedPayment: Int
    switch settlementOutcome {
    case .complete: expectedPayment = offer.reward + offer.deposit
    case .failed:
      expectedPayment = offer.failureReward + (offer.refundOnFailure ? offer.deposit : 0)
    default: expectedPayment = 0
    }
    return station.valid && acceptedAt.isFinite && (0...1e12).contains(acceptedAt)
      && boardRevision >= 0 && PackValidation.identifier(provider)
      && PackValidation.version(version)
      && digest.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil
      && (deadline.map { $0.isFinite && $0 >= acceptedAt && $0 <= 1e12 } ?? true)
      && (clock == .local || clock == .flight)
      && offer.status == .available
      && deadline == (offer.duration == 0 ? nil : acceptedAt + offer.duration)
      && (settled
        ? (settlementOutcome != nil && settlementAmount != nil && settledAt != nil)
        : (settlementOutcome == nil && settlementAmount == nil && settledAt == nil))
      && settlementOutcome != .active
      && (settlementAmount.map { (0...8_589_934_590).contains($0) } ?? true)
      && (settledAt.map { $0.isFinite && $0 >= acceptedAt && $0 <= 1e12 } ?? true)
      && (!settled || settlementAmount == expectedPayment)
      && (settlementOutcome != .complete || deadline == nil || settledAt! < deadline!)
  }
}
public struct ScriptContractState: Codable, Sendable, Equatable {
  public var boards: [String: ScriptContractBoard] = [:]
  public init() {}
  var valid: Bool {
    let identities = boards.values.flatMap { $0.offers.map(\.id) }
    return boards.count <= 128 && Set(identities).count == identities.count
      && boards.allSatisfy { $0.key == $0.value.cacheKey && $0.value.valid }
  }
}

public struct ContractAcceptanceQuote: Sendable {
  public let board: String
  public let offer: UUID
  public let issues: [String]
  public var allowed: Bool { issues.isEmpty }
  let resources: Commander
  let epoch: UUID
}
extension Commander {
  var contractQuoteResources: Commander {
    var copy = self
    copy.scriptState.flightSeconds = 0
    copy.scriptState.localSeconds = 0
    copy.scriptState.calendarSeconds = 0
    copy.scriptState.transitSeconds = 0
    return copy
  }
  var contractsValid: Bool {
    guard contracts.valid else { return false }
    for board in contracts.boards.values {
      for offer in board.offers {
        if case .accepted(let id) = offer.status {
          var frozen = offer
          frozen.status = .available
          guard let job = scriptState.instances[id]?.contract,
            job.offer.id == offer.id, job.boardKey == board.cacheKey,
            job.station == board.station, job.digest == board.digest, job.version == board.version,
            job.boardRevision == board.revision, job.group == board.group, job.clock == board.clock,
            job.offer == frozen
          else { return false }
        }
      }
    }
    return scriptState.instances.allSatisfy { _, instance in
      guard let job = instance.contract else { return true }
      return job.valid && job.digest == instance.digest && job.version == instance.version
        && instance.id == Game.contractJobIdentity(job.offer.id)
        && instance.definition.hasPrefix(job.provider + "/")
        && (instance.outcome == .active
          ? !job.settled : job.settled && job.settlementOutcome == instance.outcome)
    }
  }
}
