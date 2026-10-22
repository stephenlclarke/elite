import Foundation

extension Game {
  /// Typed row subjects and actions retain actual custody; display labels are never parsed as IDs.
  public func inventoryInformationRows(width: Double) -> [InventoryInformationRow] {
    let contentWidth = min(680, width - 48)
    var rows: [InventoryInformationRow] = []
    func append(
      _ text: String, _ ink: Ink, subject: InventorySubject? = nil,
      preview: InventoryActionPreview? = nil
    ) {
      let actionSpace =
        preview?.command == nil
        ? 0 : InventoryInteraction.actionWidth + InventoryInteraction.actionGap
      let columns = max(12, Int((contentWidth - actionSpace) / (6 * GameTypography.scale)))
      for (index, line) in MissionNotice.wrap(text, width: columns).enumerated() {
        rows.append(
          .init(line, ink, subject: index == 0 ? subject : nil, preview: index == 0 ? preview : nil)
        )
      }
    }
    func action(_ subject: InventorySubject) {
      let preview = inventoryActionPreview(for: subject)
      append(preview.detail, .cyan, subject: subject, preview: preview)
      for line in preview.extraDetails { append(line, .cyan) }
    }
    append("Trade cargo and hold totals", .yellow)
    append(
      "Cargo: \(commander.cargoTonnes) tonnes"
        + (commander.unlimitedCargo ? " (unlimited capacity)" : "/\(commander.capacity)"), .white)
    for index in commander.cargo.indices where commander.cargo[index] > 0 {
      append(
        Commodity.all[index].name + ": \(commander.cargo[index]) \(Commodity.all[index].unit)"
          + (index == 10 && commander.markedFirearms > 0 ? " (1 mission item)" : ""),
        CommodityCategory.at(index).ink)
    }
    append("Protected property - not ordinary trade cargo", .yellow)
    append("Hold totals include protected and reserved space.", .cyan)
    if commander.nativeCaptiveCount > 0 {
      append(
        "Captured crew: \(commander.nativeCaptiveCount) (included once in Slaves tonnes)", .orange)
    }
    if commander.rescuedPodTonnes > 0 {
      append("Rescued occupied capsules: \(commander.rescuedPodTonnes)t protected hold", .orange)
    }
    for id in commander.missionProgress.keys.sorted() {
      let title =
        missionPacks.entries.first { $0.pack.stateID == id }?.pack.mission.title ?? "Missing pack"
      for (key, quantity) in commander.missionProgress[id]!.payloads.sorted(by: { $0.key < $1.key })
      where quantity > 0 {
        append(
          "Reserved " + String(title.prefix(18)) + ": " + String(key.prefix(14)) + " \(quantity)t",
          .cyan)
      }
    }
    for state in commander.scriptState.instances.values.sorted(by: {
      $0.id.uuidString < $1.id.uuidString
    }) {
      guard let cargo = state.savedOwnedCargo, !cargo.held.isEmpty else { continue }
      append(
        "Issuer-owned freight: \(cargo.held.count)t \(Commodity.all[cargo.commodity].name); reserved for its destination",
        .cyan)
    }
    if let state = measuredExtractionState,
      let source = commander.scriptState.savedMeasuredExtractionSource,
      let mission = commander.scriptState.instances[state.permission.mission]
    {
      append("Measured extraction: \(state.captures.count)/12 originals collected", .cyan)
      append(
        "Raw held: \(NativeMeasuredExtraction.rawHeld(source).count)t; graded products held: \((state.processing?.products ?? []).filter { $0.custody == .held }.count)t",
        .cyan)
      for (index, original) in source.originals.enumerated() {
        let tonnes = mission.payloads["input-\(index)"] ?? 0
        let label: String
        switch original.custody {
        case .unfilled:
          label = tonnes > 0 ? "at source; slot reserved" : "uncollected; permission closed"
        case .raw: label = "protected raw original aboard"
        case .processed: label = "consumed by linked grading operation"
        case .returned: label = "returned unpaid to Avenor owner"
        case .lost: label = "genuinely lost"
        }
        append("Original \(index + 1): \(label) / \(tonnes)t", .cyan)
      }
      append(
        "Renas: processing first, separate receiving for 890 CR. Surviving failed property returns unpaid at Avenor.",
        .cyan)
    }
    if let state = recordRecoveryState,
      let source = commander.scriptState.savedRecordRecoverySource,
      let mission = commander.scriptState.instances[state.permission.mission]
    {
      append("SENN archive-owned recorder; \(state.held.count)/1 originals held", .cyan)
      for original in source.originals {
        let tonnes = mission.payloads[original.serial.lowercased()] ?? 0
        let disposition: String
        switch original.custody {
        case .cradle:
          let identification =
            state.identification == nil
            ? "unidentified at cradle" : "identified at cradle"
          disposition = tonnes > 0 ? identification + "; slot reserved" : identification
        case .held: disposition = "held protected property"
        case .returned: disposition = "returned to archive"
        case .lost: disposition = "genuinely lost"
        }
        append("\(original.serial): \(original.name) / \(disposition) / \(tonnes)t", .cyan)
      }
      append("Return to the actual Cedamar archive; no sale, fitting or ordinary discard.", .cyan)
    }
    if let state = identifiedSalvageState,
      let source = commander.scriptState.savedIdentifiedSalvageSource,
      let mission = commander.scriptState.instances[state.permission.mission]
    {
      append("PELL depot-owned property; \(state.held.count)/2 originals held", .cyan)
      for original in source.originals {
        let tonnes = mission.payloads[original.serial.lowercased()] ?? 0
        let disposition: String
        switch original.custody {
        case .cradle:
          disposition =
            tonnes > 0 ? "reserved empty slot; original at cradle" : "original at cradle"
        case .held: disposition = "held protected property"
        case .returned: disposition = "returned to depot"
        case .lost: disposition = "genuinely lost"
        }
        append("\(original.serial): \(original.name) / \(disposition) / \(tonnes)t", .cyan)
      }
      append("Return to the actual Avenor depot; no sale, fitting or ordinary discard.", .cyan)
    }
    append("Equipment ownership", .yellow)
    if let history = commander.equipmentPurchaseHistory {
      append("Recorded purchases: \(history.paid.count)", .cyan)
    }
    if let inventory = commander.equipmentInventory {
      let items = inventory.items.sorted(by: {
        let left = equipmentName($0)
        let right = equipmentName($1)
        return left == right ? $0.id.uuidString < $1.id.uuidString : left < right
      })
      for (heading, fitted) in [("Equipment - fitted", true), ("Equipment - held", false)] {
        append(heading, .yellow)
        let group = items.filter { ($0.location != nil) == fitted }
        if group.isEmpty { append("None", .cyan) }
        for item in group {
          append(equipmentName(item), .white)
          let fitting =
            item.location.map {
              equipmentSlot($0.slot)
                + ($0.hullInstanceID == inventory.activeHull ? "" : " (other hull)")
            } ?? "Held"
          append("  " + fitting + " - " + equipmentOrigin(item.provenance), .cyan)
          if let source = RecoveredFeatureDevices.source(
            for: item, ledger: commander.salvageLedger),
            case .technology(_, let quality, let condition) = source.content
          {
            append(
              String(
                format: "  Recovered quality %d; condition %d%%; mass %.1f kg",
                quality.rawValue, condition, source.massKg), .cyan)
          }
          action(.equipment(item))
        }
      }
    } else {
      append("Equipment - fitted (legacy acquisition unknown)", .yellow)
      for text in commander.laserMountSummary { append("  " + text, .white) }
      for name in commander.equipment.sorted()
      where LaserKind.from(name) == nil && !["Fuel", "Missile"].contains(name) {
        append("  " + name, .white)
      }
      append("Equipment - held", .yellow)
      append("No owned-item storage records in this legacy fit.", .cyan)
    }
    if let native = commander.alienStorageState?.current {
      for (storage, held) in native.salvage.storedTechnology.sorted(by: {
        $0.key.uuidString < $1.key.uuidString
      }) {
        guard case .technology(let definition, _, _, _) = held.item.content,
          definition == AlienMissileDefinition.recipe.requiredDefinitionID,
          held.item.provenance == .alien
        else { continue }
        append("Recovered alien artefact " + storage.uuidString.prefix(8), .white)
        action(.alienResearch(storage))
      }
      append("Alien modules - separate physical fittings", .yellow)
      for kind in AlienModuleKind.allCases {
        let summary = commander.fittedAlienSummary(kind)
        let label = SalvageDefinitions.definition(id: kind.definitionID)?.label ?? kind.rawValue
        if kind == .hyperspaceDrive {
          append(label + ": " + String(summary.count) + " fitted; immediate, no mass lock", .cyan)
        } else {
          append(
            String(format: "%@: %d fitted; +%.2f%%", label, summary.count, summary.percent), .cyan)
        }
      }
      let sources = Dictionary(uniqueKeysWithValues: native.snapshot.sources.map { ($0.id, $0) })
      for item in native.snapshot.attachments.sorted(by: { $0.id.uuidString < $1.id.uuidString }) {
        if case .retired = item.disposition { continue }
        let label =
          SalvageDefinitions.definition(id: item.kind.definitionID)?.label ?? item.kind.rawValue
        append(label + " " + item.id.uuidString.prefix(8), .white)
        if item.kind == .hyperspaceDrive {
          append("Immediate hyperspace; no hyperspace mass lock", .cyan)
        } else {
          append(
            String(format: "Contribution +%.2f%%", Double(item.contributionBasisPoints) / 100),
            .cyan)
        }
        if item.kind == .hyperspaceDrive, let source = sources[item.source] {
          let section = source.lot.identity.section
          let wreck = section.wreck
          append(
            "Recovery: G\(wreck.system.galaxy + 1) system \(wreck.system.system), wreck \(wreck.site), section \(section.section), lot \(source.lot.identity.lot)",
            .cyan)
        }
        action(.alienAttachment(item.id))
      }
      for item in native.snapshot.upgrades.sorted(by: { $0.id.uuidString < $1.id.uuidString }) {
        guard item.disposition == .stored else { continue }
        let label =
          SalvageDefinitions.definition(id: item.kind.upgradeDefinitionID)?.label
          ?? item.kind.rawValue
        append(label + " " + item.id.uuidString.prefix(8), .white)
        action(.alienUpgrade(item.id))
      }
    }
    if !commander.salvageLedger.inventory.isEmpty {
      append("Salvage hold", .yellow)
      for lot in commander.salvageLedger.inventory {
        guard case .technology(let id, let quality, let condition) = lot.content else { continue }
        append(SalvageDefinitions.definition(id: id)?.label ?? "Recovered technology", .white)
        append(
          String(
            format: "Quality %d; condition %d%%; mass %.1f kg", quality.rawValue, condition,
            lot.massKg), .cyan)
        action(.recovered(lot))
      }
    }
    return rows
  }
}
