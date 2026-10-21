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

extension Game {
  func scriptEquipmentSnapshot(_ instance: ScriptInstance) -> ScriptValue {
    let present = Set(commander.equipmentInventory?.items.map(\.id) ?? [])
    return .object(
      instance.gearIssues.mapValues { record in
        .object([
          "status": .string(record.status.rawValue), "loan": .bool(record.loan),
          "consumed": .integer(Int64(record.consumed.count)),
          "remaining": .integer(Int64(record.items.filter { present.contains($0) }.count)),
          "items": .array(record.items.map { .string($0.uuidString) }),
        ])
      })
  }

  func applyScriptGearCommand(
    _ command: ScriptValue, event: ScriptEvent, pack: ScriptPack, state: inout ScriptInstance,
    candidate: inout Commander
  ) throws -> (String, [String: ScriptValue])? {
    do {
      guard let fields = command.object, let op = fields["op"]?.string,
        let receipt = fields["id"]?.string, PackValidation.localID(receipt),
        let key = fields["gear"]?.string,
        let definition = pack.manifest.equipment?.first(where: { $0.id == key }),
        pack.manifest.capabilities.contains("owned-equipment-v2"), state.outcome == .active,
        event.instance == state.id, event.sequence > 0, docked, dockedAtMainStation
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
      try candidate.prepareEquipment()
      // A previous command in this same handler may already have changed its staged issue.
      candidate.scriptState.instances[state.id] = state
      let commandID = ScriptIdentity.uuid(
        "script-gear-command-v2:\(event.instance):\(event.sequence):\(receipt)")
      let result: (String, [String: ScriptValue])?
      if op == "gear.issue" {
        result = try issueScriptGear(
          definition, fields: fields, command: commandID, state: &state, candidate: &candidate)
      } else {
        guard let record = state.gearIssues[key], record.status == .issued,
          record.valid(for: state), record.source?.mission == state.id
        else { throw MissionPackError("The original unsettled equipment issue is required.") }
        if op == "gear.store" || op == "gear.refit" {
          result = try refitScriptGear(
            record, fields: fields, fitted: op == "gear.refit", command: commandID,
            state: &state, candidate: &candidate)
        } else {
          result = try settleScriptGear(
            record, release: op == "gear.release", command: commandID,
            state: &state, candidate: &candidate)
        }
      }
      state.receipts.insert(receipt)
      candidate.scriptState.instances[state.id] = state
      return result
    } catch let error as MissionPackError {
      throw error
    } catch let error as EquipmentIssueError {
      let message: String
      switch error {
      case .missingOriginal:
        message = "Original issued equipment is missing; substitute items cannot settle this issue."
      case .consumedOriginalRequired:
        message = "This equipment contract requires every original item to be returned."
      case .foreignLoan:
        message = "The selected fit belongs to another mission's loan."
      case .loanModificationRefused:
        message = "Historical equipment condition prevents this fitting change."
      case .unsupportedReplacement:
        message =
          "This change would reduce the current fit or cannot restore its displaced original."
      case .invalidBudget:
        message = "The resulting equipment, cargo or accommodation cannot fit this ship."
      default:
        message = "The equipment request no longer matches its original issue and current fit."
      }
      throw MissionPackError(message)
    } catch is OwnedEquipmentError {
      throw MissionPackError(
        "The exact equipment item, mount, pylon or inventory capacity is unavailable.")
    } catch {
      // This boundary performs value-only migration and provider calls, with no filesystem work.
      throw MissionPackError("The saved equipment state cannot authorize this mission request.")
    }
  }
}
