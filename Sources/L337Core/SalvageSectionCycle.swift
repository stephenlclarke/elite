import Foundation

/// One original cutting budget, shared by the ordinary ledger and native hot work.
/// An emitted batch always consumes the budget, even if the section still has loot.
/// This calculation has no collection, ownership, scene or persistence authority.
enum SalvageSectionCycle {
  enum Step: Sendable, Equatable {
    case progress(AlienStorageWorldProgress, seconds: Double)
    case released(AlienStorageWorldProgress, lots: [SalvageLot], depleted: Bool)
    case blocked, capacityRefused, alreadyDepleted
  }

  static func advance(
    plan: SalvageLootPlan, progress: AlienStorageWorldProgress, destroyed: Bool,
    partialWork: Double, damagedTechnology: Bool, section: SalvageSectionProfile,
    pose: ShipPose, velocity: Vector3, angularVelocity: Vector3,
    tool: SalvageTool, elapsed: Double, availableEmissionSlots: Int?
  ) -> Step {
    guard !destroyed else { return .alreadyDepleted }
    guard progress.issued.count == plan.items.count,
      progress.discarded.count == plan.items.count
    else { return .blocked }
    var issued = progress.issued
    var discarded = progress.discarded
    var nextLot = progress.nextLot
    var issuedStructural = progress.issuedStructural
    let material = progress.materialKind ?? (tool == .cutter ? .alloys : .minerals)
    if tool == .miningLaser || damagedTechnology {
      for index in issued.indices where issued[index] == 0 {
        if case .technology = plan.items[index].content {
          issued[index] = 1
          discarded[index] = true
        }
      }
    }
    func state() -> AlienStorageWorldProgress {
      .init(
        issued: issued, discarded: discarded, structuralUnits: progress.structuralUnits,
        issuedStructural: issuedStructural, materialKind: material, nextLot: nextLot)
    }
    let next = min(section.workSeconds, partialWork + elapsed)
    if next < section.workSeconds { return .progress(state(), seconds: next) }
    var items: [SalvageLootItem] = []
    func append(_ item: SalvageLootItem) -> Bool {
      guard nextLot < 65536 else { return false }
      items.append(item)
      nextLot += 1
      return true
    }
    if issuedStructural < progress.structuralUnits {
      guard nextLot < 65536,
        append(
          SalvageLotEmission.structural(
            plan: plan, quantity: progress.structuralUnits, material: material,
            identity: .init(section: plan.section, lot: UInt16(nextLot))))
      else { return .capacityRefused }
      issuedStructural = progress.structuralUnits
    }
    for index in issued.indices {
      let item = plan.items[index]
      while issued[index] < SalvageLotEmission.quantity(item) && items.count < 8 {
        guard nextLot < 65536 else { return .capacityRefused }
        let quantity = min(
          SalvageLotEmission.chunkLimit(item), SalvageLotEmission.quantity(item) - issued[index])
        let value = SalvageLotEmission.chunk(
          item, identity: .init(section: plan.section, lot: UInt16(nextLot)), quantity: quantity)
        guard append(value) else { return .capacityRefused }
        issued[index] += quantity
      }
    }
    // Preserve the original refusal order: pool admission precedes release geometry.
    if let availableEmissionSlots, items.count > availableEmissionSlots {
      return .capacityRefused
    }
    let normal = pose.orientation.apply(section.normal) * (1 / section.normal.length)
    let cardinal = abs(normal.x) < 0.8 ? Vector3(1, 0, 0) : Vector3(0, 1, 0)
    let cross = normal.cross(cardinal)
    let tangent = cross * (1 / cross.length)
    let offset = pose.orientation.apply(section.localPosition)
    let lots = items.enumerated().map { index, item -> SalvageLot in
      let content: SalvageLotContent
      switch item.content {
      case .commodity(let amount): content = .commodity(amount)
      case .technology(let id, let quality, let condition, _):
        content = .technology(definitionID: id, quality: quality, conditionPercent: condition)
      }
      return .init(
        identity: item.identity, content: content,
        position: pose.position + offset + normal * (item.halfExtents.length + 10)
          + tangent * Double(index % 5) * 8,
        velocity: velocity + angularVelocity.cross(offset) + normal * 3,
        halfExtents: item.halfExtents, massKg: item.massKg, loot: item)
    }
    guard lots.allSatisfy({ $0.position.length.isFinite && $0.velocity.length.isFinite }) else {
      return .blocked
    }
    let complete =
      issuedStructural == progress.structuralUnits
      && zip(issued, plan.items).allSatisfy { $0 == SalvageLotEmission.quantity($1) }
    return .released(state(), lots: lots, depleted: complete)
  }
}
