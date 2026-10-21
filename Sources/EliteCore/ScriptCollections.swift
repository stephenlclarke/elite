import Foundation

public struct ScriptCollectionItem: Codable, Sendable, Equatable {
  public let commodity: Int
  public let unit: String
  public let quantity: Int
  var valid: Bool {
    Commodity.all.indices.contains(commodity) && Commodity.all[commodity].unit == unit
      && (1...1_000_000).contains(quantity)
  }
  var gramsPerUnit: Int { unit == "t" ? 1_000_000 : unit == "kg" ? 1000 : 1 }
}
public struct ScriptCollectionDefinition: Codable, Sendable, Equatable {
  public let id: String
  public let title: String
  public let galaxy: Int
  public let system: Int
  public let items: [ScriptCollectionItem]
  var valid: Bool {
    PackValidation.localID(id) && (1...96).contains(title.count)
      && (0..<8).contains(galaxy) && (0..<256).contains(system)
      && (1...17).contains(items.count) && items.allSatisfy(\.valid)
      && Set(items.map(\.commodity)).count == items.count
  }
}
public struct ScriptCollectionLot: Codable, Sendable, Equatable {
  public let instance: UUID
  public let sequence: UInt64
  public let revision: UInt64
  public let dialogue: String
  public let items: [ScriptCollectionItem]
  public let cause: ScriptEventContext
  public let committed: ScriptEventContext
  public var massGrams: Int { items.reduce(0) { $0 + $1.quantity * $1.gramsPerUnit } }
  func valid(
    for state: ScriptInstance, engine: ScriptEngineState, definition: ScriptCollectionDefinition
  )
    -> Bool
  {
    instance == state.id && sequence > 0 && sequence <= engine.nextEvent
      && state.hasAcknowledged(sequence) && revision > 0 && revision <= state.revision
      && PackValidation.localID(dialogue) && (1...17).contains(items.count)
      && items.allSatisfy(\.valid) && Set(items.map(\.commodity)).count == items.count
      && items.allSatisfy { item in
        definition.items.contains { $0.commodity == item.commodity && $0.unit == item.unit }
      }
      && cause.valid && committed.valid && cause.mainStation && committed.mainStation
      && cause.galaxy == definition.galaxy && cause.system == definition.system
      && committed.galaxy == definition.galaxy && committed.system == definition.system
      && cause.revision < revision && committed.revision == revision
      && cause.localSeconds <= committed.localSeconds
      && committed.localSeconds <= engine.localSeconds
      && cause.flightSeconds <= committed.flightSeconds
      && committed.flightSeconds <= engine.flightSeconds
      && cause.calendarSeconds <= committed.calendarSeconds
      && committed.calendarSeconds <= engine.calendarSeconds
      && cause.transitSeconds <= committed.transitSeconds
      && committed.transitSeconds <= engine.transitSeconds
  }
}
public struct ScriptCollection: Codable, Sendable, Equatable {
  public let definition: ScriptCollectionDefinition
  public var lots: [UInt64: ScriptCollectionLot] = [:]
  public func delivered(_ commodity: Int) -> Int {
    lots.values.reduce(0) { total, lot in
      total + lot.items.reduce(0) { $0 + ($1.commodity == commodity ? $1.quantity : 0) }
    }
  }
  public var complete: Bool {
    definition.items.allSatisfy { delivered($0.commodity) == $0.quantity }
  }
  func valid(for state: ScriptInstance, engine: ScriptEngineState) -> Bool {
    definition.valid && lots.count <= 1024
      && lots.allSatisfy { key, lot in
        key == lot.sequence && lot.valid(for: state, engine: engine, definition: definition)
      }
      && definition.items.allSatisfy { delivered($0.commodity) <= $0.quantity }
  }
}
public struct ScriptCollectionQuoteItem: Codable, Sendable, Equatable {
  public let commodity: Int
  public let unit: String
  public let requested: Int
  public let delivered: Int
  public let aboard: Int
  public let available: Int
  public var outstanding: Int { requested - delivered }
  public var quantity: Int { min(outstanding, available) }
  var valid: Bool {
    Commodity.all.indices.contains(commodity) && Commodity.all[commodity].unit == unit
      && (1...1_000_000).contains(requested) && (0...requested).contains(delivered)
      && (0...Int.max / 17).contains(aboard) && (0...aboard).contains(available)
  }
  var value: ScriptValue {
    .object([
      "commodity": .integer(Int64(commodity)), "unit": .string(unit),
      "name": .string(Commodity.all[commodity].name), "requested": .integer(Int64(requested)),
      "delivered": .integer(Int64(delivered)), "outstanding": .integer(Int64(outstanding)),
      "aboard": .integer(Int64(aboard)), "available": .integer(Int64(available)),
      "quantity": .integer(Int64(quantity)),
    ])
  }
}
public struct ScriptCollectionQuote: Codable, Sendable, Equatable {
  public let collection: String
  public let items: [ScriptCollectionQuoteItem]
  var positive: Bool { items.contains { $0.quantity > 0 } }
  var valid: Bool {
    PackValidation.localID(collection) && (1...17).contains(items.count)
      && items.allSatisfy(\.valid) && Set(items.map(\.commodity)).count == items.count
  }
}

extension ScriptInstance {
  public var collections: [String: ScriptCollection] {
    get { savedCollections ?? [:] }
    set { savedCollections = newValue.isEmpty ? nil : newValue }
  }
  func collectionsValid(engine: ScriptEngineState) -> Bool {
    guard collections.count <= 32,
      collections.allSatisfy({ key, value in
        key == value.definition.id && value.valid(for: self, engine: engine)
      }),
      collections.values.reduce(0, { $0 + $1.lots.count }) <= 1024,
      Set(collections.values.flatMap { $0.lots.keys }).count
        == collections.values.reduce(0, { $0 + $1.lots.count })
    else { return false }
    // Reject malformed quantities before computing the cumulative values used by a saved quote.
    if let quote = dialogue?.collectionQuote {
      guard quote.valid, let collection = collections[quote.collection],
        quote.items.count == collection.definition.items.count,
        zip(quote.items, collection.definition.items).allSatisfy({ item, requirement in
          item.commodity == requirement.commodity && item.unit == requirement.unit
            && item.requested == requirement.quantity
            && item.delivered == collection.delivered(item.commodity)
        })
      else { return false }
    }
    return true
  }
}

extension Game {
  func collectionQuote(_ id: String, state: ScriptInstance, commander candidate: Commander? = nil)
    -> ScriptCollectionQuote?
  {
    let commander = candidate ?? self.commander
    guard let collection = state.collections[id], docked, dockedAtMainStation,
      commander.galaxy == collection.definition.galaxy,
      commander.system == collection.definition.system
    else { return nil }
    return .init(
      collection: id,
      items: collection.definition.items.map { item in
        .init(
          commodity: item.commodity, unit: item.unit, requested: item.quantity,
          delivered: collection.delivered(item.commodity), aboard: commander.cargo[item.commodity],
          available: commander.sellableCargo(item.commodity))
      })
  }
  func collectionQuoteFresh(_ dialogue: ScriptDialogue, state: ScriptInstance) -> Bool {
    guard let quote = dialogue.collectionQuote else { return true }
    return quote == collectionQuote(quote.collection, state: state)
  }
  var offeredCollectionText: String? {
    guard let quote = scriptPresentedDialogue?.collectionQuote else { return nil }
    var rows = ["Materials for this handoff:"]
    for item in quote.items {
      rows.append(
        "\(Commodity.all[item.commodity].name): transfer \(item.quantity) \(item.unit); outstanding \(item.outstanding) \(item.unit); available \(item.available) \(item.unit)."
      )
    }
    rows.append(
      quote.positive
        ? "Confirm transfers these quantities once."
        : "No requested unreserved materials are available. Acquire goods before returning to this contact."
    )
    return rows.joined(separator: "\n\n")
  }
  func collectionQuery(_ state: ScriptInstance) -> ScriptValue {
    .object(
      state.collections.mapValues { collection in
        let items = collection.definition.items.map { item in
          ScriptValue.object([
            "commodity": .integer(Int64(item.commodity)), "unit": .string(item.unit),
            "requested": .integer(Int64(item.quantity)),
            "delivered": .integer(Int64(collection.delivered(item.commodity))),
            "outstanding": .integer(Int64(item.quantity - collection.delivered(item.commodity))),
          ])
        }
        return .object([
          "title": .string(collection.definition.title), "complete": .bool(collection.complete),
          "galaxy": .integer(Int64(collection.definition.galaxy)),
          "system": .integer(Int64(collection.definition.system)), "items": .array(items),
          "quote": collectionQuote(collection.definition.id, state: state).map {
            .array($0.items.map(\.value))
          } ?? .null,
        ])
      })
  }
  func applyCollectionCommand(
    _ command: ScriptValue, event: ScriptEvent, pack: ScriptPack,
    state: inout ScriptInstance, candidate: inout Commander
  ) throws -> (String, [String: ScriptValue])? {
    guard let fields = command.object, let op = fields["op"]?.string,
      let id = fields["id"]?.string, state.outcome == .active,
      pack.manifest.capabilities.contains("partial-collections-v2"),
      let definition = pack.manifest.collections?.first(where: { $0.id == id })
    else { throw MissionPackError("Collection requests require a declared active collection.") }
    if op == "collection.ensure" {
      guard Set(fields.keys) == ["op", "id"] else {
        throw MissionPackError("Unexpected collection authorization field.")
      }
      if let existing = state.collections[id] {
        guard existing.definition == definition else {
          throw MissionPackError("Material collection requires an explicit content migration.")
        }
      } else {
        state.collections[id] = .init(definition: definition)
      }
      return nil
    }
    guard op == "collection.deliver", Set(fields.keys) == ["op", "id", "token"],
      let dialogue = state.dialogue, let quote = dialogue.collectionQuote,
      let declared = pack.manifest.dialogs?.first(where: { $0.id == dialogue.id }),
      declared.collection == id, (declared.choices ?? []).isEmpty,
      let expected = collectionQuote(id, state: state), quote == expected, quote.positive,
      var collection = state.collections[id], collection.definition == definition,
      state.collections.values.reduce(0, { $0 + $1.lots.count }) < 1024,
      collection.lots[event.sequence] == nil, let cause = event.context
    else {
      throw MissionPackError("Review current positive materials at the assigned orbital station.")
    }
    // This operation is itself the real confirmation. A story flag or a prior callback cannot grant it.
    try applyScriptCommand(
      .object([
        "op": .string("dialogue.commit"), "id": .string(dialogue.id), "token": fields["token"]!,
      ]), event: event, pack: pack, state: &state, candidate: &candidate)
    let items = quote.items.filter { $0.quantity > 0 }.map {
      ScriptCollectionItem(commodity: $0.commodity, unit: $0.unit, quantity: $0.quantity)
    }
    for item in items {
      guard candidate.sellableCargo(item.commodity) >= item.quantity else {
        throw MissionPackError("The available material lot changed before confirmation.")
      }
      candidate.cargo[item.commodity] -= item.quantity
    }
    var committed = state
    committed.revision += 1
    let lot = ScriptCollectionLot(
      instance: state.id, sequence: event.sequence,
      revision: committed.revision, dialogue: dialogue.id, items: items, cause: cause,
      committed: scriptEventContext(committed))
    collection.lots[event.sequence] = lot
    state.collections[id] = collection
    return (
      "collection.delivered",
      [
        "collection_id": .string(id),
        "lot_sequence": .integer(Int64(event.sequence)),
        "mass_grams": .integer(Int64(lot.massGrams)),
        "complete": .bool(collection.complete),
      ]
    )
  }
}

extension ScriptPackLibrary {
  static func validateCollections(_ manifest: ScriptManifest) throws {
    let definitions = manifest.collections ?? []
    let ids = Set(definitions.map(\.id))
    let required = manifest.mission.requiredCollections ?? []
    guard definitions.count <= 32 && ids.count == definitions.count,
      definitions.allSatisfy(\.valid), Set(required).count == required.count,
      Set(required).isSubset(of: ids),
      definitions.isEmpty
        || (manifest.capabilities.contains("partial-collections-v2")
          && manifest.capabilities.contains("story-v2")),
      (manifest.dialogs ?? []).allSatisfy({ dialog in
        dialog.collection.map { ids.contains($0) && (dialog.choices ?? []).isEmpty } ?? true
      }),
      !manifest.handlers.contains(where: { $0.event == "collection.delivered" })
        || manifest.capabilities.contains("partial-collections-v2")
    else {
      throw MissionPackError("Invalid, duplicate or unsupported native material collections.")
    }
  }
}
