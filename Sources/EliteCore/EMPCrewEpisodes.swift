import Foundation

struct EMPCrewEjection: Equatable, Codable, Sendable {
  let ordinal: Int
  let delay: Double
  var emittedAt: Double?
}

struct EMPLegacyCrewEjection: Equatable, Codable, Sendable {
  let ordinal: Int
  let time: Double
}

/// Timing evidence. Electrical recovery and traffic ownership stay with the runtime.
struct EMPCrewDisableEpisode: Equatable, Codable, Sendable {
  let incident: CombatIncident
  var ejections: [EMPCrewEjection]
  let legacyTiming: Bool
  var actorBindings: [ActorIdentity]
  let legacyPods: [Int]
  let legacyNextEjectionAt: Double?
  var legacyEmissions: [EMPLegacyCrewEjection]
  var deadline: Double { incident.physicalTime + 30 }
  func valid(source: ActorIdentity, crewTotal: Int) -> Bool {
    incident.id > 0 && incident.kind == .emp && incident.outcome == .hit
      && incident.victim?.system == source.system && (incident.victim?.entity ?? 0) > 1
      && incident.origin.owner.entity == 0 && incident.origin.owner.system == source.system
      && incident.origin.owner.visit == incident.victim?.visit
      && incident.physicalTime.isFinite && incident.physicalTime >= 0
      && deadline.isFinite && incident.origin.emittedAt == incident.physicalTime
      && (legacyTiming ? ejections.isEmpty : (1...crewTotal).contains(ejections.count))
      && (legacyTiming
        || (legacyPods.isEmpty && legacyEmissions.isEmpty && legacyNextEjectionAt == nil))
      && legacyPods.count <= crewTotal && legacyEmissions.count <= crewTotal
      && legacyPods == Array(0..<legacyPods.count)
      && (!legacyTiming
        || legacyNextEjectionAt.map { $0.isFinite && $0 >= incident.physicalTime } == true)
      && legacyEmissions.enumerated().allSatisfy { index, entry in
        (0..<crewTotal).contains(entry.ordinal) && entry.time.isFinite && entry.time < deadline
          && entry.time
            >= (index == 0
              ? (legacyNextEjectionAt ?? .infinity) : legacyEmissions[index - 1].time + 1)
      }
      && (1...EMPState.maximumPeople).contains(actorBindings.count)
      && Set(actorBindings).count == actorBindings.count
      && actorBindings.first == incident.victim
      && actorBindings.allSatisfy {
        $0.system == source.system && $0.entity > 1
          && $0.visit >= (incident.victim?.visit ?? UInt64.max)
      }
      && Set(ejections.map(\.ordinal)).count == ejections.count
      && ejections.allSatisfy { entry in
        (0..<crewTotal).contains(entry.ordinal) && entry.delay.isFinite
          && (0.5...45).contains(entry.delay)
          && (entry.emittedAt.map {
            $0.isFinite && $0 >= incident.physicalTime + entry.delay && $0 < deadline
          } ?? true)
      }
  }
}

extension EMPCrewDisableEpisode {
  private enum CodingKeys: String, CodingKey {
    case incident, ejections, legacyTiming, actorBindings, legacyPods, legacyNextEjectionAt,
      legacyEmissions
  }
  init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    guard
      let schedule = try NativePeopleDecoding.array(
        values, key: .ejections, type: EMPCrewEjection.self)
    else { throw SaveError.invalidCommander }
    guard
      let bindings = try NativePeopleDecoding.array(
        values, key: .actorBindings, type: ActorIdentity.self)
    else { throw SaveError.invalidCommander }
    guard let legacyPods = try NativePeopleDecoding.array(values, key: .legacyPods, type: Int.self),
      let legacyEmissions = try NativePeopleDecoding.array(
        values, key: .legacyEmissions, type: EMPLegacyCrewEjection.self)
    else { throw SaveError.invalidCommander }
    self.init(
      incident: try values.decode(CombatIncident.self, forKey: .incident), ejections: schedule,
      legacyTiming: try values.decode(Bool.self, forKey: .legacyTiming), actorBindings: bindings,
      legacyPods: legacyPods,
      legacyNextEjectionAt: try values.decodeIfPresent(Double.self, forKey: .legacyNextEjectionAt),
      legacyEmissions: legacyEmissions)
  }
}

extension EMPHullRecord {
  static let maximumDisableEpisodes = 32
  var disableEpisodes: [EMPCrewDisableEpisode] { savedDisableEpisodes ?? [] }
  var currentCrewDisableIncident: CombatIncident {
    disableEpisodes.last?.incident ?? disableIncident
  }
  var aboardOrdinals: [Int] {
    guard (1...EMPState.maximumPeople).contains(crewTotal) else { return [] }
    return (0..<crewTotal).filter { crewOutcome(ordinal: $0) == .aboard }
  }
  func podIndex(for ordinal: Int) -> Int? {
    pods.firstIndex { $0.body.physical?.empCrewPod == .init(source: source, ordinal: ordinal) }
  }
  func nextDueCrew(at time: Double) -> Int? {
    guard time.isFinite, let episode = disableEpisodes.last, time < episode.deadline else {
      return nil
    }
    if episode.legacyTiming { return time >= nextEjectionAt ? aboardOrdinals.first : nil }
    return episode.ejections.filter {
      crewOutcome(ordinal: $0.ordinal) == .aboard
        && episode.incident.physicalTime + $0.delay <= time
    }.min {
      ($0.delay, $0.ordinal) < ($1.delay, $1.ordinal)
    }?.ordinal
  }
  /// Called only by the actual-zero producer, once for the original surviving complement.
  mutating func appendCrewDisableEpisode(incident: CombatIncident, ejections: [EMPCrewEjection])
    -> Bool
  {
    if disableEpisodes.isEmpty, incident != disableIncident {
      var candidate = self
      guard candidate.installLegacyCrewEpisode(),
        candidate.appendCrewDisableEpisode(incident: incident, ejections: ejections)
      else { return false }
      self = candidate
      return true
    }
    guard let victim = incident.victim else { return false }
    let episode = EMPCrewDisableEpisode(
      incident: incident, ejections: ejections, legacyTiming: false, actorBindings: [victim],
      legacyPods: [], legacyNextEjectionAt: nil, legacyEmissions: [])
    guard !terminal, crewAboard > 0, disableEpisodes.count < Self.maximumDisableEpisodes,
      episode.valid(source: source, crewTotal: crewTotal),
      Set(ejections.map(\.ordinal)) == Set(aboardOrdinals),
      disableEpisodes.isEmpty || incident.victim == hull.body.physical?.identity,
      disableEpisodes.last.map({
        incident.id > $0.incident.id && incident.physicalTime >= $0.deadline
      })
        ?? (incident == disableIncident)
    else { return false }
    savedDisableEpisodes = disableEpisodes + [episode]
    nextEjectionAt = incident.physicalTime + (ejections.map(\.delay).min() ?? 45)
    return true
  }
  var crewCensusValid: Bool {
    guard (1...EMPState.maximumPeople).contains(crewTotal), pods.count <= crewTotal,
      crewCaptures.count <= EMPState.maximumPeople,
      disableEpisodes.count <= Self.maximumDisableEpisodes,
      savedDisableEpisodes == nil || !disableEpisodes.isEmpty,
      savedDeceasedOrdinals == nil || !deceasedOrdinals.isEmpty,
      (0...crewTotal).contains(lostCrewCount), deceasedOrdinals.count == lostCrewCount
    else { return false }
    let ejected = pods.compactMap { $0.body.physical?.empCrewPod?.ordinal }
    let captured = crewCaptures.flatMap(\.ordinals)
    let discharged = ejected + captured + deceasedOrdinals
    guard discharged.count <= crewTotal, Set(discharged).count == discharged.count,
      discharged.allSatisfy({ (0..<crewTotal).contains($0) }), ejected.count == pods.count,
      disableEpisodes.allSatisfy({ $0.valid(source: source, crewTotal: crewTotal) }),
      disableEpisodes.first.map({ $0.incident == disableIncident }) ?? true,
      disableEpisodes.enumerated().allSatisfy({ index, episode in
        index == 0
          || (episode.incident.id > disableEpisodes[index - 1].incident.id
            && episode.incident.physicalTime >= disableEpisodes[index - 1].deadline)
      })
    else { return false }
    if let current = disableEpisodes.last {
      guard
        current.legacyTiming
          || Set(aboardOrdinals).isSubset(of: Set(current.ejections.map(\.ordinal)))
      else { return false }
      if !current.legacyTiming, savedDeceasedOrdinals != nil,
        !Set(deceasedOrdinals).isSubset(of: Set(current.ejections.map(\.ordinal)))
      {
        return false
      }
    } else if savedCrewCaptures != nil || savedDeceasedOrdinals != nil {
      return false
    } else if !pods.enumerated().allSatisfy({
      $0.element.body.physical?.empCrewPod?.ordinal == $0.offset
    }) {
      return false
    }
    // Historical schedules retain discharged IDs, but no later episode can reissue them.
    for (index, episode) in disableEpisodes.enumerated() {
      let members = Set(episode.ejections.map(\.ordinal))
      if index == 0, !episode.legacyTiming, members != Set(0..<crewTotal) { return false }
      if episode.legacyTiming && (index != 0 || episode.incident != disableIncident) {
        return false
      }
      if index > 0, !disableEpisodes[index - 1].legacyTiming,
        !members.isSubset(of: Set(disableEpisodes[index - 1].ejections.map(\.ordinal)))
      {
        return false
      }
      if crewCaptures.contains(where: {
        $0.physicalTime < episode.incident.physicalTime && !members.isDisjoint(with: $0.ordinals)
      }) {
        return false
      }
      if disableEpisodes.prefix(index).contains(where: { prior in
        prior.ejections.contains { $0.emittedAt != nil && members.contains($0.ordinal) }
          || prior.legacyPods.contains(where: { members.contains($0) })
          || prior.legacyEmissions.contains(where: { members.contains($0.ordinal) })
      }) {
        return false
      }
    }
    let emissions = disableEpisodes.flatMap(\.ejections).filter { $0.emittedAt != nil }
    let legacy =
      disableEpisodes.flatMap(\.legacyPods)
      + disableEpisodes.flatMap(\.legacyEmissions).map(\.ordinal)
    let emittedOrdinals = emissions.map(\.ordinal) + legacy
    guard Set(emittedOrdinals).count == emittedOrdinals.count,
      emissions.allSatisfy({ podIndex(for: $0.ordinal) != nil }),
      Set(emittedOrdinals).isDisjoint(with: captured)
    else { return false }
    if !disableEpisodes.isEmpty {
      // Only the frozen legacy prefix has unknown historical timing.
      guard Set(ejected) == Set(emittedOrdinals) else { return false }
    }
    return true
  }

  mutating func recordCrewEjection(ordinal: Int, at time: Double) -> Bool {
    guard var episodes = savedDisableEpisodes, let index = episodes.indices.last else {
      return false
    }
    if episodes[index].legacyTiming {
      guard time.isFinite, time >= nextEjectionAt, time < episodes[index].deadline,
        crewOutcome(ordinal: ordinal) == .aboard,
        episodes[index].legacyEmissions.count < EMPState.maximumPeople
      else { return false }
      episodes[index].legacyEmissions.append(.init(ordinal: ordinal, time: time))
      savedDisableEpisodes = episodes
      return true
    }
    guard
      let entry = episodes[index].ejections.firstIndex(where: { $0.ordinal == ordinal }),
      episodes[index].ejections[entry].emittedAt == nil,
      time >= episodes[index].incident.physicalTime + episodes[index].ejections[entry].delay,
      time < episodes[index].deadline
    else { return false }
    // Schedule delay and original ID never change after sampling.
    episodes[index].ejections[entry].emittedAt = time
    savedDisableEpisodes = episodes
    return true
  }

  mutating func installLegacyCrewEpisode() -> Bool {
    guard disableEpisodes.isEmpty, crewCaptures.isEmpty, let original = disableIncident.victim,
      let current = hull.body.physical?.identity
    else { return false }
    let episode = EMPCrewDisableEpisode(
      incident: disableIncident, ejections: [], legacyTiming: true,
      actorBindings: original == current ? [original] : [original, current],
      legacyPods: pods.compactMap { $0.body.physical?.empCrewPod?.ordinal },
      legacyNextEjectionAt: nextEjectionAt, legacyEmissions: [])
    guard episode.valid(source: source, crewTotal: crewTotal) else { return false }
    savedDisableEpisodes = [episode]
    return true
  }

  mutating func recordCrewActorBinding(_ actor: ActorIdentity) -> Bool {
    guard var episodes = savedDisableEpisodes, let index = episodes.indices.last else {
      return false
    }
    let old = episodes[index]
    if old.actorBindings.contains(actor) { return true }
    guard old.actorBindings.count < EMPState.maximumPeople else { return false }
    var changed = old
    changed.actorBindings.append(actor)
    guard changed.valid(source: source, crewTotal: crewTotal) else { return false }
    episodes[index] = changed
    savedDisableEpisodes = episodes
    return true
  }
}

extension Game {
  mutating func sampleEMPCrewEjections(ordinals: [Int]) -> [EMPCrewEjection] {
    ordinals.map { ordinal in
      // Native seeded simulation RNG, independent of the classic galaxy generator.
      .init(ordinal: ordinal, delay: 0.5 + Double(randomByte()) / 255 * 44.5)
    }
  }
}

extension EMPHullRecord {
  func crewEpisodeTimelineValid(flight: FlightSimulationState) -> Bool {
    disableEpisodes.allSatisfy { episode in
      let incident = episode.incident
      return incident.id < flight.nextIncident && incident.origin.emissionID < flight.nextEmission
        && incident.physicalTime <= flight.physicalTime
        && (incident.victim?.visit ?? UInt64.max) <= flight.visit
        && (incident.victim?.entity ?? UInt64.max) < flight.nextActor
        && episode.ejections.allSatisfy { ($0.emittedAt ?? 0) <= flight.physicalTime }
        && episode.legacyEmissions.allSatisfy { $0.time <= flight.physicalTime }
        && episode.actorBindings.allSatisfy {
          $0.visit <= flight.visit && $0.entity < flight.nextActor
        }
    }
  }
}
