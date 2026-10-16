import Foundation

/// Read-only facts from the displayed shop. Creating these facts allocates no identities.
/// The explicit user action wraps them in an intent; the runtime creates the actual transaction.
public struct EquipmentPurchaseContext: Sendable, Equatable {
  fileprivate let commander: Commander
  fileprivate let epoch: InventoryContextEpoch
  fileprivate let selection: Int
  fileprivate let mount: LaserMount
  fileprivate let workTool: Bool
  fileprivate let price: Int

  fileprivate init(game: Game) {
    commander = game.commander
    epoch = game.inventoryContextEpoch
    selection = game.selection
    mount = game.equipmentMount
    workTool = game.equipmentWorkTool
    price =
      Equipment.all.indices.contains(game.selection)
      ? game.shopPrice(Equipment.all[game.selection]) : -1
  }
}

public enum EquipmentMutationIntent: Sendable, Equatable {
  case purchase(EquipmentPurchaseContext)
  case inventory(InventoryCommand)
}

public enum EquipmentMutationReceipt: Sendable, Equatable {
  case purchase(item: String, physicalItem: UUID?, fitted: Bool)
  case inventory(ownedRevision: UInt64, sourceRevision: UInt64)
}

public enum EquipmentMutationRefusal: Sendable, Equatable {
  case staleContext, unavailable
  case rewardOnly(String)
  case storageFull, missileRackFull
  case insufficientFunds
  case missingPurchasedPrerequisite(String)
  case missingFittedPrerequisite(String)
  case notForSale, alreadyOwned, noCompatibleFitting, fittingUnavailable, invalidState

  var message: String {
    switch self {
    case .staleContext: "FITTING CHANGED - REFRESH INVENTORY"
    case .unavailable: "NOT AVAILABLE"
    case .rewardOnly(let label): label.uppercased() + " - NOT FOR SALE"
    case .storageFull: "FUEL STORAGE FULL"
    case .missileRackFull: "MISSILE RACK FULL"
    case .insufficientFunds: "NOT ENOUGH CASH"
    case .missingPurchasedPrerequisite(let key): "BUY " + key.uppercased() + " FIRST"
    case .missingFittedPrerequisite(let key): "FIT " + key.uppercased() + " FIRST"
    case .notForSale: "STANDARD OR ACQUISITION HARDWARE - NOT FOR SALE"
    case .alreadyOwned: "ALREADY OWNED"
    case .noCompatibleFitting: "NO COMPATIBLE FREE FITTING"
    case .fittingUnavailable: "FITTING REFUSED - CHECK CURRENT INVENTORY"
    case .invalidState: "PURCHASE REFUSED"
    }
  }
}

public enum EquipmentMutationResult: Sendable, Equatable {
  case applied(EquipmentMutationReceipt)
  case refused(EquipmentMutationRefusal)

  public var applied: Bool {
    if case .applied = self { return true }
    return false
  }
}

extension Game {
  public var equipmentPurchaseContext: EquipmentPurchaseContext? {
    guard screen == .equipment, docked, !paused, Equipment.all.indices.contains(selection) else {
      return nil
    }
    return .init(game: self)
  }

  /// Compatibility for direct value-model callers. Native input uses the actor's captured intent.
  mutating func purchaseImmediately() -> EquipmentMutationResult {
    performShopPurchase(.init(game: self), requireEquipmentScreen: false)
  }

  mutating func performEquipmentMutation(_ intent: EquipmentMutationIntent)
    -> EquipmentMutationResult
  {
    switch intent {
    case .purchase(let context): return performShopPurchase(context, requireEquipmentScreen: true)
    case .inventory(let command): return performInventoryMutation(command)
    }
  }

  private mutating func performShopPurchase(
    _ context: EquipmentPurchaseContext, requireEquipmentScreen: Bool
  ) -> EquipmentMutationResult {
    guard docked, !paused, !requireEquipmentScreen || screen == .equipment,
      inventoryContextEpoch == context.epoch, commander == context.commander,
      selection == context.selection, equipmentMount == context.mount,
      equipmentWorkTool == context.workTool, Equipment.all.indices.contains(selection),
      shopPrice(Equipment.all[selection]) == context.price
    else {
      notify(EquipmentMutationRefusal.staleContext.message)
      return .refused(.staleContext)
    }
    let item = Equipment.all[selection]
    let refusal: EquipmentMutationRefusal
    do {
      guard commander.valid, context.price >= 0 else { throw ShopRefusal(.invalidState) }
      if Equipment.isReward(item.name) && !atPlugh {
        throw ShopRefusal(.rewardOnly(Equipment.rewardLabel(item.name)))
      }
      if item.name == FuelStorage.equipmentName,
        commander.fuelStorageUnits >= FuelStorage.maximumCount
      {
        throw ShopRefusal(.storageFull)
      }
      let receipt: EquipmentMutationReceipt
      if item.name == "Missile", commander.missiles >= commander.missileCapacity {
        throw ShopRefusal(.missileRackFull)
      }
      if item.name == "Fuel" {
        guard equipmentAvailable(item), commander.availableCredits >= context.price else {
          throw ShopRefusal(.unavailable)
        }
        var planned = commander
        planned.fuel = commander.fuelCapacity
        if !commander.unlimitedCash { planned.credits -= context.price }
        guard planned.valid else { throw ShopRefusal(.invalidState) }
        commander = planned
        receipt = .purchase(item: item.name, physicalItem: nil, fitted: true)
      } else {
        let quote = try quoteEquipmentPurchase(item)
        let fitted = try applyEquipmentPurchase(quote)
        receipt = .purchase(item: item.name, physicalItem: quote.request.newItem, fitted: fitted)
      }
      inventoryContextEpoch = .init()
      if case .purchase(_, _, let fitted) = receipt {
        notify(fitted ? "EQUIPMENT FITTED" : "EQUIPMENT STORED - CURRENT FIT RETAINED")
      }
      return .applied(receipt)
    } catch let error as ShopRefusal {
      refusal = error.reason
    } catch EquipmentPurchaseError.missingPrerequisite(let node) {
      refusal = .missingPurchasedPrerequisite(node.key)
    } catch EquipmentPurchaseError.missingFittedPrerequisite(let node) {
      refusal = .missingFittedPrerequisite(node.key)
    } catch EquipmentPurchaseError.notForSale {
      refusal = .notForSale
    } catch EquipmentPurchaseError.insufficientFunds {
      refusal = .insufficientFunds
    } catch EquipmentRuntimeError.unavailable {
      refusal = .unavailable
    } catch EquipmentRuntimeError.alreadyOwned {
      refusal = .alreadyOwned
    } catch EquipmentRuntimeError.noSlot {
      refusal = .noCompatibleFitting
    } catch {
      refusal = .invalidState
    }
    notify(refusal.message)
    return .refused(refusal)
  }
}

private struct ShopRefusal: Error {
  let reason: EquipmentMutationRefusal
  init(_ reason: EquipmentMutationRefusal) { self.reason = reason }
}

extension GameRuntime {
  /// There is no suspension between validation and publication. Every reader sees one whole state.
  public func equipmentTransaction(_ intent: EquipmentMutationIntent) -> EquipmentMutationResult {
    game.performEquipmentMutation(intent)
  }
}
