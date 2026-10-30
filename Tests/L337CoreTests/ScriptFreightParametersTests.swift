import Foundation
import Testing

@testable import L337Core

private func originalFreightParameters(_ plan: ScriptFreightPlan) -> ScriptValue? {
  guard let bytes = try? JSONEncoder().encode(plan),
    let value = try? JSONDecoder().decode(ScriptValue.self, from: bytes)
  else { return nil }
  return .object(["freight": value])
}

private func freightProjectionPlan(
  _ original: ScriptFreightPlan, calendar: Double
) -> ScriptFreightPlan {
  .init(
    profile: original.profile, generatorRevision: original.generatorRevision,
    variant: original.variant, content: original.content, owner: original.owner,
    boardRevision: original.boardRevision, seedHex: original.seedHex, origin: original.origin,
    reach: original.reach, row: original.row, initialState: original.initialState,
    draws: original.draws, finalState: original.finalState, routeIndex: original.routeIndex,
    commodityIndex: original.commodityIndex, path: original.path,
    calendarLowerBoundSeconds: calendar, template: original.template,
    deliveryContact: original.deliveryContact, abandonContact: original.abandonContact,
    capabilities: original.capabilities, bondedHazardTiers: original.bondedHazardTiers,
    supply: original.supply, bondedQuote: original.bondedQuote)
}

private func freightProjectionEdit(
  _ plan: ScriptFreightPlan, edit: (inout [String: Any]) throws -> Void
) throws -> ScriptFreightPlan {
  var fields = try #require(
    JSONSerialization.jsonObject(with: JSONEncoder().encode(plan)) as? [String: Any])
  try edit(&fields)
  let decoder = JSONDecoder()
  decoder.nonConformingFloatDecodingStrategy = .convertFromString(
    positiveInfinity: "inf", negativeInfinity: "-inf", nan: "nan")
  return try decoder.decode(
    ScriptFreightPlan.self, from: JSONSerialization.data(withJSONObject: fields))
}

struct ScriptFreightParametersTests {
  @Test func everyStringLeafKeepsOriginalUTF8LimitWithoutAnAggregateBudget() throws {
    let fixture = try ScriptFreightFixture()
    defer { fixture.clean() }
    let original = try #require(fixture.plans(try fixture.policyGame()).first)
    let base = try freightProjectionEdit(original) { fields in
      fields["supply"] =
        [
          "batch": "batch", "stockUnits": 16, "commodity": 10, "issuerContact": "arlen",
          "galaxy": 0, "system": 7, "receiverSystem": 185,
        ] as [String: Any]
    }
    let paths = [
      ["profile"], ["variant"], ["content", "provider"], ["content", "version"],
      ["content", "digest"], ["content", "state_id"], ["content", "board_id"],
      ["seed_hex"], ["origin", "stationClass"], ["reach", "revision"], ["reach", "hull"],
      ["template", "id"], ["template", "title"], ["delivery_contact"], ["abandon_contact"],
      ["capabilities"], ["supply", "batch"], ["supply", "issuerContact"],
    ]
    let limit = String(repeating: "\u{00e9}", count: 131072)
    for path in paths {
      for text in [limit, limit + "x"] {
        let plan = try freightProjectionEdit(base) { fields in
          if path.count == 1 {
            fields[path[0]] = path[0] == "capabilities" ? [text] as Any : text as Any
          } else {
            var nested = try #require(fields[path[0]] as? [String: Any])
            nested[path[1]] = text
            fields[path[0]] = nested
          }
        }
        #expect(plan.parameters == originalFreightParameters(plan))
        #expect((plan.parameters != nil) == (text.utf8.count <= 262144))
      }
    }
    let combined = try freightProjectionEdit(base) { fields in
      fields["profile"] = limit
      fields["template"] = ["id": "freight-goods", "title": limit]
    }
    let parameters = try #require(combined.parameters)
    #expect(parameters == originalFreightParameters(combined))
  }

  @Test func everyVariableArrayKeepsOriginalCountLimit() throws {
    let fixture = try ScriptFreightFixture()
    defer { fixture.clean() }
    let original = try #require(fixture.plans(try fixture.policyGame()).first)
    for key in ["draws", "path", "capabilities", "bondedHazardTiers"] {
      for count in [16384, 16385] {
        let plan = try freightProjectionEdit(original) { fields in
          fields[key] =
            key == "capabilities"
            ? Array(repeating: "x", count: count) as Any
            : Array(repeating: 0, count: count) as Any
        }
        #expect(plan.parameters == originalFreightParameters(plan))
        #expect((plan.parameters != nil) == (count <= 16384))
      }
    }
  }

  @Test func generatedProfilesMatchOriginalCodecAndCanonicalRead() throws {
    let fixture = try ScriptFreightFixture()
    defer { fixture.clean() }
    var game = try fixture.policyGame()
    let packs = [
      fixture.pack,
      try ScriptPackLibrary.read(ScriptPackLibrary.bundledBondedFreightDirectory),
      try ScriptPackLibrary.read(ScriptPackLibrary.bundledConsentedFreightDirectory),
    ]
    for pack in packs {
      game.commander.system = pack.manifest.freight?.supply?.system ?? 0
      let plans = try ScriptFreightGeneration.plans(
        pack: pack, commander: game.commander, origin: game.contractStation,
        revision: 0, seed: 0x0123_4567_89ab_cdef)
      try #require(!plans.isEmpty)
      for plan in plans {
        try #require(plan.valid)
        let parameters = try #require(plan.parameters)
        #expect(parameters == originalFreightParameters(plan))
        #expect(ScriptFreightPlan.read(parameters) == plan)
      }
    }
  }

  @Test func optionalFieldsUnicodeUUIDAndIntegerLimitsMatchOriginalCodec() throws {
    let fixture = try ScriptFreightFixture()
    defer { fixture.clean() }
    let game = try fixture.policyGame()
    let original = try #require(fixture.plans(game).first)
    let edited = try freightProjectionEdit(original) { fields in
      fields["owner"] = "ABCDEF12-3456-7890-ABCD-EF1234567890"
      fields["board_revision"] = Int64.min
      fields["draws"] = [UInt32.min, UInt32.max]
      fields["path"] = [Int.min, Int.max]
      fields["template"] = ["id": "freight-goods", "title": "Caf\u{00e9} \u{1f680} / \"goods\"\n"]
      fields["bondedHazardTiers"] = [Int.min, 0, Int.max]
      fields["bondedQuote"] = ["routeLegs": Int.max, "hazardTier": Int.min]
      fields["supply"] =
        [
          "batch": "batch", "stockUnits": Int.max, "commodity": Int.min,
          "issuerContact": "contact", "galaxy": 0, "system": 7, "receiverSystem": 185,
        ] as [String: Any]
      var reach = try #require(fields["reach"] as? [String: Any])
      reach.removeValue(forKey: "navigation")
      reach.removeValue(forKey: "jumpFuelMultiplier")
      reach.removeValue(forKey: "fullTankReach")
      fields["reach"] = reach
    }
    #expect(edited.parameters == originalFreightParameters(edited))
    #expect(edited.parameters?["freight"]?["owner"]?.string == edited.owner.uuidString)
    for tier in NavigationTier.allCases {
      let plan = try freightProjectionEdit(edited) { fields in
        var reach = try #require(fields["reach"] as? [String: Any])
        reach["navigation"] = tier.rawValue
        reach["jumpFuelMultiplier"] = 0.125
        reach["fullTankReach"] = 17.75
        fields["reach"] = reach
      }
      #expect(plan.parameters == originalFreightParameters(plan))
    }
  }

  @Test func finiteNumericBoundariesAndEveryNonfiniteFieldMatchOriginalCodec() throws {
    let fixture = try ScriptFreightFixture()
    defer { fixture.clean() }
    let original = try #require(fixture.plans(try fixture.policyGame()).first)
    let values: [Double] = [
      0, -0.0, 1, -1, 0.125, Double(1).nextUp, Double.leastNonzeroMagnitude,
      Double.leastNormalMagnitude, Double.greatestFiniteMagnitude,
      Double(Int64.min).nextDown, Double(Int64.min), Double(Int64.min).nextUp,
      Double(Int64.max).nextDown, Double(Int64.max), Double(Int64.max).nextUp,
      9_007_199_254_740_991, 9_007_199_254_740_992, 9_007_199_254_740_994,
      .infinity, -.infinity, .nan,
    ]
    for value in values {
      let plan = freightProjectionPlan(original, calendar: value)
      #expect(plan.parameters == originalFreightParameters(plan))
      if !value.isFinite { #expect(plan.parameters == nil) }
    }
    for key in ["jumpCap", "firstReach", "jumpFuelMultiplier", "fullTankReach"] {
      for token in ["inf", "-inf", "nan"] {
        let plan = try freightProjectionEdit(original) { fields in
          var reach = try #require(fields["reach"] as? [String: Any])
          reach[key] = token
          fields["reach"] = reach
        }
        #expect(plan.parameters == nil && originalFreightParameters(plan) == nil)
      }
    }
  }
}
