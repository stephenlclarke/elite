import Foundation
import Testing

@testable import EliteCore

struct NativeCrewLogHistoricalLoaderUnitTests {
  private func pack() throws -> ScriptPack {
    try ScriptPackLibrary.read(ScriptPackLibrary.bundledInductionCrewLogDirectory)
  }

  private func manifest(
    _ original: ScriptManifest, changing edit: (inout [String: Any]) throws -> Void
  ) throws -> ScriptManifest {
    var fields = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
    try edit(&fields)
    return try JSONDecoder().decode(
      ScriptManifest.self, from: JSONSerialization.data(withJSONObject: fields))
  }

  @Test func bundledC08LoadRetainsOriginalDigestGeometryAndAuthorizedRecorderFit() throws {
    let pack = try pack()
    #expect(pack.digest == "29f26ad4f1382ea23c3cced3b7cc609c00e6617ef7d07a52e669f7d067d2602b")
    #expect(NativeInductionCrewLogPack.matches(pack))
    let model = NativeInductionCrewLogSource.recorderModel
    let historical = try NativeInductionCrewLogHistoricalGeometry.design.get()
    #expect(pack.models[model] == historical && pack.models.count == 2)
    let loaded = try ScriptPackLibrary.readNPCModels(
      pack.manifest, directory: ScriptPackLibrary.bundledInductionCrewLogDirectory)
    #expect(loaded.designs == pack.models)
    #expect(loaded.bytes == pack.resourceBytes)
    let hash = ScriptPackLibrary.hash(try ScriptPackLibrary.canonicalGeometry(historical))
    #expect(hash == NativeInductionCrewLogSource.recorderGeometry)
    let f = try CrewLogProducerFixture()
    let parent = f.parent
    let fit = ScriptNPCFit(definition: f.source.recorder, models: [model: hash])
    #expect(f.source.matchesFit(fit, recorder: true))
    #expect(fit.definition.scale == 0.2 && fit.definition.model == "catalogue:SH058")
    #expect(abs(try NativeInductionCrewLogSource.recorderRadius.get() - 6.322963883093118) < 1e-9)
    #expect(f.source.manifest.occupants(of: f.source.manifest.recorder).isEmpty)
    #expect(f.source.manifest.massTonnes == 1 && f.parent == parent)
  }

  @Test func futureLiveBrabantCannotSupplyC08ButOrdinaryCatalogueLookupIsUnchanged() throws {
    let pack = try pack()
    let brabant = try OriginalFleetShowroomModels.model(for: "SH058").nativeDesign
    let model = NativeInductionCrewLogSource.recorderModel
    let historical = try NativeInductionCrewLogHistoricalGeometry.design.get()
    try #require(brabant != historical)
    var calls: [String] = []
    let original = try ScriptPackLibrary.catalogueNPCDesign(
      model, manifest: pack.manifest,
      live: { id in
        calls.append(id)
        return brabant
      })
    #expect(original == historical && calls.isEmpty)
    let ordinary = try manifest(pack.manifest) { $0["id"] = "test.ordinary-catalogue" }
    let live = try ScriptPackLibrary.catalogueNPCDesign(
      model, manifest: ordinary,
      live: { id in
        calls.append(id)
        return brabant
      })
    #expect(live == brabant && calls == ["SH058"])
    let other = try #require(ShipCatalogue.ship("SH141")?.design)
    let otherResult = try ScriptPackLibrary.catalogueNPCDesign(
      "catalogue:SH141", manifest: pack.manifest,
      live: { id in
        calls.append(id)
        return ShipCatalogue.ship(id)?.design
      })
    #expect(otherResult == other && calls == ["SH058", "SH141"])
    let retained = try #require(original)
    #expect(
      try ScriptPackLibrary.canonicalGeometry(retained)
        == ScriptPackLibrary.canonicalGeometry(historical))
  }

  @Test func changedIdentityVersionOrRecorderBindingsCannotClaimHistoricalOverride() throws {
    let pack = try pack()
    let model = NativeInductionCrewLogSource.recorderModel
    let brabant = try OriginalFleetShowroomModels.model(for: "SH058").nativeDesign
    for field in [
      "id", "mission", "version", "recorder-id", "recorder-source", "recorder-model",
      "recorder-scale", "extra-recorder", "extra-component",
    ] {
      let changed = try manifest(pack.manifest) { values in
        switch field {
        case "id": values["id"] = "test.other-pack"
        case "version": values["version"] = "2.0.0"
        case "mission":
          var mission = try #require(values["mission"] as? [String: Any])
          mission["id"] = "other-job"
          values["mission"] = mission
        default:
          var npcs = try #require(values["npcs"] as? [[String: Any]])
          let recorder = try #require(
            npcs.firstIndex { ($0["id"] as? String) == "induction-crew-custody-recorder" })
          switch field {
          case "recorder-id": npcs[recorder]["id"] = "substitute-recorder"
          case "recorder-source": npcs[recorder]["source"] = "substitute-source"
          case "recorder-model": npcs[recorder]["model"] = "catalogue:SH141"
          case "recorder-scale": npcs[recorder]["scale"] = 0.21
          case "extra-recorder": npcs.append(npcs[recorder])
          default:
            var components = try #require(npcs[0]["components"] as? [[String: Any]])
            components[0]["model"] = model
            npcs[0]["components"] = components
          }
          values["npcs"] = npcs
        }
      }
      #expect(!NativeInductionCrewLogHistoricalGeometry.applies(to: changed, reference: model))
      var calls = 0
      let result = try ScriptPackLibrary.catalogueNPCDesign(
        model, manifest: changed,
        live: { _ in
          calls += 1
          return brabant
        })
      #expect(result == brabant && calls == 1)
      // Even a retained digest value cannot bypass the existing exact identity/profile guards.
      let forged = ScriptPack(
        manifest: changed, source: pack.source, manifestBytes: pack.manifestBytes,
        digest: pack.digest, models: pack.models, resourceBytes: pack.resourceBytes,
        entryBytes: pack.entryBytes)
      #expect(!NativeInductionCrewLogPack.matches(forged))
    }
  }

  @Test func modifiedPackBytesAndHistoricalAuthenticationFailureCannotFallbackOrGainAuthority()
    throws
  {
    let original = try pack()
    let copy = FileManager.default.temporaryDirectory.appendingPathComponent(
      "c08-loader-" + UUID().uuidString)
    try FileManager.default.copyItem(
      at: ScriptPackLibrary.bundledInductionCrewLogDirectory, to: copy)
    defer { try? FileManager.default.removeItem(at: copy) }
    let entry = copy.appendingPathComponent(original.manifest.module)
    var bytes = try Data(contentsOf: entry)
    bytes.append(Data("\n-- Changed input must not retain native C08 authority.\n".utf8))
    try bytes.write(to: entry)
    let changed = try ScriptPackLibrary.read(copy)
    #expect(changed.models == original.models && changed.digest != original.digest)
    #expect(!NativeInductionCrewLogPack.matches(changed))
    let brabant = try OriginalFleetShowroomModels.model(for: "SH058").nativeDesign
    var fallbackCalls = 0
    #expect(throws: (any Error).self) {
      try ScriptPackLibrary.catalogueNPCDesign(
        NativeInductionCrewLogSource.recorderModel, manifest: original.manifest,
        live: { _ in
          fallbackCalls += 1
          return brabant
        },
        historicalRecorder: {
          try NativeInductionCrewLogHistoricalGeometry.authenticate(brabant, sourceID: "SH058")
        })
    }
    #expect(fallbackCalls == 0)
    #expect(original.digest == NativeInductionCrewLogPack.digest)
    #expect(NativeInductionCrewLogPack.matches(original))
  }
}
