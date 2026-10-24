import Foundation
import Testing

@testable import EliteCore

@Test func contractAndRRSReviewResourcesRemainFrozenAcrossNestedMutations() {
  var source = Commander()
  source.cargo[0] = 2
  let station = ScriptStationResource(identity: UUID(), galaxy: 0, system: 7)
  source.scriptState.stationResources[station.key] = station
  let original = source
  let token = UUID()
  let contract = ContractAcceptanceQuote(
    board: "snapshot", offer: UUID(), issues: [], resources: source, epoch: UUID(),
    reviewToken: token)
  let rrs = RRSCourierQuote(
    row: .abandon(UUID()), resources: source, epoch: UUID(), board: nil,
    destination: nil, arrival: nil, issues: ["No actual station authority"])

  source.credits += 10
  source.cargo[0] = 9
  source.equipment.insert("Fuel Scoops")
  source.scriptState.stationResources[station.key]?.energy = 50
  #expect(source != original)
  #expect(contract.resources == original && rrs.resources == original)

  for var readback in [contract.resources, rrs.resources] {
    readback.credits = 0
    readback.cargo[0] = 0
    readback.equipment.removeAll()
    readback.scriptState.stationResources[station.key]?.destroyed = true
    #expect(readback != original)
    #expect(contract.resources == original && rrs.resources == original)
  }
  var copied = contract
  copied.reviewToken = UUID()
  #expect(contract.reviewToken == token)
  #expect(copied.resources == original && !rrs.allowed)
}
