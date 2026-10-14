import CryptoKit
import Foundation

public struct ScriptGearDefinition: Codable, Sendable {
  public let id: String
  public let name: String
  public let quantity: Int
  public let loan: Bool
  public let mount: String?
  public let returnPolicy: String?
  var kind: OwnedGearKind? {
    if let laser = LaserKind.from(name) { return .laser(laser) }
    if name == "Missile" { return .missile }
    if name == FuelStorage.equipmentName { return .fuelStorage }
    let module = OwnedGearKind.module(name)
    return module.valid ? module : nil
  }
  var valid: Bool {
    PackValidation.localID(id) && kind != nil && (1...32).contains(quantity)
      && (returnPolicy == nil || ["all", "remaining"].contains(returnPolicy!))
      && (mount == nil || (LaserKind.from(name) != nil && LaserMount(rawValue: mount!) != nil))
  }
  func slot(_ index: Int) -> OwnedGearSlot {
    switch kind! {
    case .laser: .laser(LaserMount(rawValue: mount ?? "front")!)
    case .missile: .pylon(index)
    case .fuelStorage: .fuelStorage(index % FuelStorage.maximumCount)
    case .module(let name): .module(name)
    }
  }
}
public enum ScriptGearStatus: String, Codable, Sendable { case issued, returned, released }
public struct ScriptGearIssue: Codable, Sendable, Equatable {
  public let resource: String
  public let kind: OwnedGearKind
  public let items: [UUID]
  public let loan: Bool
  public let returnRemaining: Bool
  public var status: ScriptGearStatus = .issued
  public var consumed: Set<UUID> = []
  var valid: Bool {
    PackValidation.localID(resource) && kind.valid && (1...32).contains(items.count)
      && Set(items).count == items.count && consumed.isSubset(of: Set(items))
      && (status != .released || loan)
      && (status != .returned || returnRemaining || consumed.isEmpty)
  }
}
extension OwnedGear {
  static func issuedIdentity(mission: UUID, resource: String, index: Int) -> UUID {
    let source = "issued-player-gear-v1:\(mission):\(resource):\(index)"
    let b = Array(SHA256.hash(data: Data(source.utf8)))
    return UUID(
      uuid: (
        b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7], b[8], b[9], b[10], b[11], b[12], b[13],
        b[14], b[15]
      ))
  }
}
extension Commander {
  var issuedEquipmentValid: Bool {
    let items = ownedEquipment?.items ?? []
    guard Set(items.map(\.id)).count == items.count else { return false }
    let byID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
    for item in items {
      guard let mission = item.issuedBy else {
        if item.sourceResource != nil || item.loanOwner != nil { return false }
        continue
      }
      guard let resource = item.sourceResource,
        let record = scriptState.instances[mission]?.gearIssues[resource],
        record.items.contains(item.id), record.kind == item.kind,
        record.status != .returned, !record.consumed.contains(item.id),
        item.loanOwner == (record.loan && record.status == .issued ? mission : nil)
      else { return false }
    }
    for instance in scriptState.instances.values {
      for record in instance.gearIssues.values {
        for identity in record.items {
          let present = byID[identity] != nil
          if record.status == .returned || record.consumed.contains(identity) {
            if present { return false }
          } else if record.loan && record.status == .issued && !present {
            return false
          }
        }
      }
    }
    return true
  }
}
extension Game {
  func scriptEquipmentSnapshot(_ instance: ScriptInstance) -> ScriptValue {
    .object(
      instance.gearIssues.mapValues { record in
        .object([
          "status": .string(record.status.rawValue), "loan": .bool(record.loan),
          "consumed": .integer(Int64(record.consumed.count)),
          "remaining": .integer(
            Int64(
              record.items.filter { id in
                commander.ownedEquipment?.items.contains { $0.id == id } == true
              }.count)),
          "items": .array(record.items.map { .string($0.uuidString) }),
        ])
      })
  }
  func applyScriptGearCommand(
    _ command: ScriptValue, pack: ScriptPack, state: inout ScriptInstance,
    candidate: inout Commander
  ) throws -> (String, [String: ScriptValue])? {
    guard let fields = command.object, let op = fields["op"]?.string,
      let receipt = fields["id"]?.string, PackValidation.localID(receipt),
      let key = fields["gear"]?.string,
      let definition = pack.manifest.equipment?.first(where: { $0.id == key }),
      pack.manifest.capabilities.contains("owned-equipment-v2"), state.outcome == .active,
      docked, dockedAtMainStation
    else {
      throw MissionPackError("Declared owned equipment and a main orbital station are required.")
    }
    let allowed: Set<String>
    switch op {
    case "gear.issue": allowed = ["op", "id", "gear", "fit"]
    case "gear.return", "gear.release": allowed = ["op", "id", "gear"]
    case "gear.store", "gear.refit": allowed = ["op", "id", "gear", "index", "mount"]
    default: throw MissionPackError("Unsupported owned-equipment command.")
    }
    guard Set(fields.keys).isSubset(of: allowed) else {
      throw MissionPackError("Unknown equipment command field.")
    }
    if state.receipts.contains(receipt) { return nil }
    candidate.synchronizeEquipmentInventory(force: true)
    let result: (String, [String: ScriptValue])?
    if op == "gear.issue" {
      result = try issueScriptGear(definition, fields: fields, state: &state, candidate: &candidate)
    } else {
      guard var record = state.gearIssues[key], record.status == .issued else {
        throw MissionPackError(
          "The original equipment issue is required and cannot be repeated after settlement.")
      }
      if op == "gear.store" || op == "gear.refit" {
        result = try refitScriptGear(
          record, fields: fields, fitted: op == "gear.refit", candidate: &candidate)
      } else {
        let identities = Set(record.items).subtracting(record.consumed)
        guard
          identities.allSatisfy({ identity in
            candidate.ownedEquipment!.items.contains {
              $0.id == identity && $0.issuedBy == state.id && $0.sourceResource == key
            }
          })
        else {
          throw MissionPackError(
            "Original issued equipment is missing; substitute items cannot settle this issue.")
        }
        if op == "gear.return" {
          guard record.returnRemaining || record.consumed.isEmpty else {
            throw MissionPackError(
              "This equipment contract requires every original item to be returned.")
          }
          candidate.ownedEquipment?.items.removeAll { identities.contains($0.id) }
          candidate.applyOwnedEquipmentFit()
          record.status = .returned
        } else {
          guard record.loan else {
            throw MissionPackError("Only this mission's own loan can be released.")
          }
          for index in candidate.ownedEquipment!.items.indices
          where identities.contains(candidate.ownedEquipment!.items[index].id) {
            candidate.ownedEquipment?.items[index].loanOwner = nil
          }
          record.status = .released
        }
        state.gearIssues[key] = record
        result = (
          op == "gear.return" ? "equipment.returned" : "equipment.released",
          [
            "gear": .string(key),
            "items": .array(
              record.items.filter { identities.contains($0) }.map { .string($0.uuidString) }),
            "consumed": .integer(Int64(record.consumed.count)),
          ]
        )
      }
    }
    state.receipts.insert(receipt)
    return result
  }
  private func issueScriptGear(
    _ definition: ScriptGearDefinition, fields: [String: ScriptValue],
    state: inout ScriptInstance, candidate: inout Commander
  ) throws -> (String, [String: ScriptValue])? {
    if state.gearIssues[definition.id] != nil { return nil }
    let fit: Bool
    if let value = fields["fit"] {
      guard case .bool(let desired) = value else {
        throw MissionPackError("Equipment fit must be true or false.")
      }
      fit = desired
    } else {
      fit = false
    }
    guard let profile = try? ShipAccommodationProfile(ship: candidate.ship),
      candidate.ownedEquipment!.items.count <= 10000 - definition.quantity
    else {
      throw MissionPackError("Owned equipment capacity is unavailable.")
    }
    let identities = (0..<definition.quantity).map {
      OwnedGear.issuedIdentity(mission: state.id, resource: definition.id, index: $0)
    }
    guard
      identities.allSatisfy({ identity in
        !candidate.ownedEquipment!.items.contains { $0.id == identity }
      })
    else {
      throw MissionPackError("An issued equipment identity already exists.")
    }
    for (index, identity) in identities.enumerated() {
      var item = OwnedGear(id: identity, kind: definition.kind!, slot: definition.slot(index))
      item.fittedSlot = nil
      item.issuedBy = state.id
      item.sourceResource = definition.id
      item.loanOwner = definition.loan ? state.id : nil
      candidate.ownedEquipment?.items.append(item)
      if fit
        && !candidate.fitOwnedGear(
          at: candidate.ownedEquipment!.items.count - 1, equipmentBudget: profile.equipmentUnits)
      {
        throw MissionPackError(
          "The issued equipment cannot fit; clear its actual mount, pylon or equipment space first."
        )
      }
    }
    state.gearIssues[definition.id] = .init(
      resource: definition.id, kind: definition.kind!, items: identities, loan: definition.loan,
      returnRemaining: definition.returnPolicy == "remaining")
    return (
      "equipment.issued",
      [
        "gear": .string(definition.id), "items": .array(identities.map { .string($0.uuidString) }),
        "loan": .bool(definition.loan),
      ]
    )
  }
  private func refitScriptGear(
    _ record: ScriptGearIssue, fields: [String: ScriptValue], fitted: Bool,
    candidate: inout Commander
  ) throws -> (String, [String: ScriptValue]) {
    guard let index = fields["index"]?.integer, (0..<Int64(record.items.count)).contains(index),
      let position = candidate.ownedEquipment?.items.firstIndex(where: {
        $0.id == record.items[Int(index)]
      }),
      let profile = try? ShipAccommodationProfile(ship: candidate.ship)
    else { throw MissionPackError("The exact original equipment item is required.") }
    let mount: LaserMount?
    if let value = fields["mount"] {
      guard let text = value.string, let requested = LaserMount(rawValue: text),
        case .laser = record.kind
      else { throw MissionPackError("A known laser mount is required.") }
      mount = requested
    } else {
      mount = nil
    }
    if fitted {
      guard
        candidate.fitOwnedGear(at: position, equipmentBudget: profile.equipmentUnits, mount: mount)
      else { throw MissionPackError("The exact issued item cannot fit this ship.") }
    } else {
      guard candidate.ownedEquipment!.items[position].fittedSlot != nil else {
        throw MissionPackError("The issued item is already stored.")
      }
      candidate.ownedEquipment?.items[position].fittedSlot = nil
      candidate.applyOwnedEquipmentFit()
    }
    return (
      "equipment.changed",
      [
        "gear": .string(record.resource), "item": .string(record.items[Int(index)].uuidString),
        "fitted": .bool(fitted),
      ]
    )
  }
}
