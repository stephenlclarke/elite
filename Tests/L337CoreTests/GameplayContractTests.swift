import Foundation
import Testing

@testable import L337Core

@Test func gameplayIdentitySeparatesVisitsAndKeepsOrePersistent() throws {
  let system = SystemIdentity(galaxy: 0, system: 7)
  let first = ActorIdentity(system: system, visit: 1, entity: 10)
  let next = ActorIdentity(system: system, visit: 2, entity: 10)
  #expect(first != next)
  let rock = RockIdentity(system: system, field: 1, rock: 2)
  let payload = PayloadIdentity.ore(rock, fragment: 0)
  let encoded = try JSONEncoder().encode(payload)
  #expect(try JSONDecoder().decode(PayloadIdentity.self, from: encoded) == payload)
  #expect(PayloadIdentity.wreck(first, lot: 0) != .wreck(next, lot: 0))
}

@Test func gameplayCommodityUnitsUseExistingMarketAuthority() {
  for commodity in CommodityIdentity.allCases {
    #expect(commodity.unit == Commodity.all[commodity.rawValue].unit)
    #expect(commodity.name == Commodity.all[commodity.rawValue].name)
  }
  #expect(CommodityIdentity.alloys.rawValue == 9)
  #expect(CommodityIdentity.minerals.rawValue == 12)
  #expect(CommodityAmount(commodity: .gold, quantity: 1).tonnes == 0)
  #expect(CommodityAmount(commodity: .platinum, quantity: 1).tonnes == 0)
  #expect(CommodityAmount(commodity: .minerals, quantity: 3).tonnes == 3)
  #expect(!CommodityAmount(commodity: .food, quantity: 0).valid)
  #expect(!CommodityAmount(commodity: .food, quantity: Int.max).valid)
}

@Test func gameplayPoseConvertsWorldAndCameraWithoutMovingAnchors() {
  var axes = Basis3()
  axes.rotate(pitch: 0.4, roll: -0.7, yaw: 1.2)
  let pose = ShipPose(position: .init(120, -30, 440), orientation: axes)
  let anchor = Vector3(-5000, 1500, 12000)
  let roundTrip = pose.systemPoint(pose.shipPoint(anchor))
  #expect((roundTrip - anchor).length < 1e-8)
  let vector = Vector3(25, 15, -10)
  #expect((pose.shipVector(axes.apply(vector)) - vector).length < 1e-8)
}

@Test func gameplayBudgetReservesDefenceAndMissionCapacity() {
  var budget = AdmissionBudget(total: 100)
  #expect(budget.ordinaryRemaining == 16)
  budget.active[.police] = 3
  budget.total += 3
  #expect(budget.ordinaryRemaining == 16)
  budget.active[.mission] = 4
  budget.total += 4
  #expect(budget.ordinaryRemaining == 16)
  budget.total = 140
  #expect(budget.ordinaryRemaining == 0)
  #expect(PopulationClass.projectile.maximum == 32)
  #expect(AdmissionPriority.mission < .police && AdmissionPriority.police < .ordinary)
}
