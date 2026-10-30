import Foundation
import Testing

@testable import L337Core

/// Structural model and codec inputs only; no native authority or runtime journey is created.
struct NativeMeasuredExtractionDomainTests {
  @Test func extractionOriginalsAreFiniteStableAndOwnerScoped() throws {
    let station = NativeMainStationIdentity(
      world: UUID(), system: NativeMeasuredExtraction.root.system, resource: UUID())
    let originals = NativeMeasuredExtraction.originals(station)
    #expect(originals.count == 12 && Set(originals.map(\.id)).count == 12)
    #expect(originals == NativeMeasuredExtraction.originals(station))
    #expect(
      originals.map(\.payload)
        == (0..<12).map {
          .ore(NativeMeasuredExtraction.root, fragment: UInt16($0))
        })
    #expect(originals.allSatisfy { $0.custody == .unfilled })
    let other = NativeMainStationIdentity(
      world: UUID(), system: station.system, resource: station.resource)
    #expect(
      Set(originals.map(\.id)).isDisjoint(
        with: NativeMeasuredExtraction.originals(other).map(\.id)))
    let bytes = try JSONEncoder().encode(originals)
    #expect(try JSONDecoder().decode([MeasuredOriginal].self, from: bytes) == originals)
  }

  @Test(arguments: [false, true])
  func fieldReliefLowersThroughMeasuredExtractionBeforeRecordRecovery(alien: Bool) {
    let upper = alien ? 58 : 57
    let middle = WayfarerFieldReliefSave.lowerSchema(upper)
    #expect(middle == (alien ? 56 : 55))
    #expect(NativeMeasuredExtractionSave.lowerSchema(middle) == (alien ? 54 : 53))
    #expect(WayfarerFieldReliefSave.lowerSchema(52) == 52)
    #expect(NativeMeasuredExtractionSave.lowerSchema(52) == 52)
    #expect(WayfarerFieldReliefSave.lowerSchema(nil) == nil)
    #expect(NativeMeasuredExtractionSave.lowerSchema(nil) == nil)
  }

  @Test(arguments: [false, true])
  func sharedClosedEnvelopeAcceptsBothBoardsAndRejectsClaimsUnderOlderVersions(alien: Bool)
    throws
  {
    let extraction = [
      "group": NativeMeasuredExtraction.stateID, "digest": NativeMeasuredExtraction.digest,
      "provider": "l337.contract", "id": NativeMeasuredExtraction.boardID,
    ]
    let relief = [
      "group": WayfarerFieldRelief.stateID, "digest": WayfarerFieldRelief.digest,
      "provider": "l337.wayfarer-service", "id": WayfarerFieldRelief.boardID,
    ]
    let both = try JSONSerialization.data(withJSONObject: [
      "boards": ["g12": extraction, "w04": relief]
    ])
    try ScriptSaveJSONPreflight.validateRepairLoopFields(
      both, part: .contracts, schema: alien ? 58 : 57)
    #expect(throws: (any Error).self) {
      try ScriptSaveJSONPreflight.validateRepairLoopFields(
        both, part: .contracts, schema: alien ? 56 : 55)
    }
    let onlyExtraction = try JSONSerialization.data(withJSONObject: ["boards": ["g12": extraction]])
    try ScriptSaveJSONPreflight.validateRepairLoopFields(
      onlyExtraction, part: .contracts, schema: alien ? 56 : 55)
    #expect(throws: (any Error).self) {
      try ScriptSaveJSONPreflight.validateRepairLoopFields(
        onlyExtraction, part: .contracts, schema: alien ? 54 : 53)
    }
  }

  @Test func closedEnvelopeRejectsMissingMeasuredLeafAndMixedNativeDeclarations() throws {
    let missingLeaf = try JSONSerialization.data(withJSONObject: [
      "instances": [
        "g12": [
          "definition": NativeMeasuredExtraction.stateID, "digest": NativeMeasuredExtraction.digest,
        ]
      ]
    ])
    #expect(throws: (any Error).self) {
      try ScriptSaveJSONPreflight.validateRepairLoopFields(missingLeaf, part: .missions, schema: 57)
    }
    var extraction = try ScriptPackLibrary.read(
      ScriptPackLibrary.bundledMeasuredExtractionDirectory
    ).manifest
    let relief = try ScriptPackLibrary.read(ScriptPackLibrary.bundledFieldReliefDirectory).manifest
    extraction.fieldRelief = relief.fieldRelief
    #expect(throws: (any Error).self) {
      try ScriptPackLibrary.validateMeasuredExtraction(extraction)
    }
    var mixedRelief = relief
    mixedRelief.measuredExtraction = extraction.measuredExtraction
    #expect(throws: (any Error).self) {
      try WayfarerFieldReliefSave.validateDeclaration(mixedRelief)
    }
  }
}
