import Foundation
import Testing

@testable import EliteCore

struct ScriptFinanceCalendarDeclarationTests {
  @Test func originalInterestExampleAuthorizesItsCalendarWithoutInventingCourierMetadata() throws {
    let fixture = try ScriptFinanceTestFixture(example: "finance-interest")
    defer { fixture.storage.clean() }
    let manifest = fixture.pack.manifest
    #expect(manifest.courier == nil && manifest.board == nil)
    #expect(manifest.loans?.first?.profile == "simple-interest-v1")
    #expect(manifest.capabilities.contains("mission-calendar-v2"))
    try ScriptPackLibrary.validateCourier(manifest)
  }

  @Test(arguments: [
    "calendar-only", "interest-free", "courier-capability", "courier-event", "mission-board",
    "invalid-terms", "missing-finance-capability",
  ])
  func interestCalendarStillRejectsUnclosedOrUnrelatedProviderAuthority(condition: String) throws {
    let fixture = try ScriptFinanceTestFixture(example: "finance-interest")
    defer { fixture.storage.clean() }
    var fields = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(fixture.pack.manifest))
        as? [String: Any])
    var loans = try #require(fields["loans"] as? [[String: Any]])
    var capabilities = try #require(fields["capabilities"] as? [String])
    switch condition {
    case "calendar-only": fields.removeValue(forKey: "loans")
    case "interest-free":
      loans[0]["profile"] = "fixed-principal-v1"
      loans[0].removeValue(forKey: "interest")
      fields["loans"] = loans
    case "courier-capability":
      capabilities.append("courier-contracts-basic-v2")
    case "courier-event":
      var handlers = try #require(fields["handlers"] as? [[String: Any]])
      handlers.append(["event": "courier.terminated", "function": "contact"])
      fields["handlers"] = handlers
    case "mission-board":
      fields["board"] = [
        "id": "finance", "title": "Finance", "generator": "board", "clock": "missionCalendar",
      ]
    case "invalid-terms":
      var interest = try #require(loans[0]["interest"] as? [String: Any])
      interest["rateBasisPoints"] = 0
      loans[0]["interest"] = interest
      fields["loans"] = loans
    default:
      capabilities.removeAll { $0 == "finance-obligations-basic-v2" }
    }
    fields["capabilities"] = capabilities
    let manifest = try JSONDecoder().decode(
      ScriptManifest.self, from: JSONSerialization.data(withJSONObject: fields))
    // Exercise this exact calendar gate: an unrelated validator cannot mask acceptance here.
    #expect(throws: (any Error).self) { try ScriptPackLibrary.validateCourier(manifest) }
  }
}
