import Testing

@testable import EliteCore

struct FlightControlAuthorityUnitTests {
  @Test func allSharedFlightBindingsRoundTripWithoutFunctionKeys() {
    let expected: [(String, FlightControlAuthority.ActionID)] = [
      ("w", .changeWeapon), ("return", .fire), ("e", .ecm), ("q", .releaseHold),
      ("tab", .nextTarget), ("f", .targetFilter),
    ]
    #expect(FlightControlAuthority.ActionID.allCases.count == expected.count)
    for (token, action) in expected {
      #expect(FlightControlInput.token(for: action) == token)
      #expect(FlightControlInput.action(for: token) == action)
      #expect(FlightControlInput.action(for: token.uppercased()) == action)
    }
    for token in ["f1", "f2", "space", "escape", "", "tab-next"] {
      #expect(FlightControlInput.action(for: token) == nil)
    }
  }

  @Test func targetSelectionAndFilterInterruptTheHeldToolWithoutBecomingFire() {
    for action in [
      FlightControlAuthority.ActionID.nextTarget, .targetFilter, .changeWeapon, .releaseHold,
    ] {
      #expect(FlightControlInput.interruptsHeldTool(action))
    }
    #expect(!FlightControlInput.interruptsHeldTool(.fire))
    #expect(!FlightControlInput.interruptsHeldTool(.ecm))
    #expect(!FlightControlInput.fireIsHeld(["tab", "f", "w", "q", "e"]))
    #expect(FlightControlInput.fireIsHeld(["tab", "f", "return"]))
  }

  @Test func generatedHelpRowsRemainBoundedAndKeepMenusScoped() {
    let rows = FlightControlAuthority.ActionID.allCases.map(FlightControlInput.helpRow)
    #expect(rows.count == 6 && Set(rows).count == 6)
    #expect(rows.allSatisfy { $0.count <= 40 })
    #expect(rows.contains("TAB - NEXT TARGET") && rows.contains("F - TARGET FILTER"))
    #expect(rows.contains("RETURN - FIRE (HOLD)"))
    #expect(rows.filter { $0.contains("(HOLD)") }.count == 1)
    #expect(
      FlightControlAuthority.helpTopics.allSatisfy {
        $0.bindings.map(\.id) == FlightControlAuthority.ActionID.allCases
          && $0.menuContext.contains("Return in a menu confirms")
      })
  }
}
