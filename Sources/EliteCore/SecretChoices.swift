import Foundation

extension Game {
  public var secretChoices: [String] {
    return [
      "0 DISPLAY: " + commander.shipDisplayStyle.label,
      "1 DOCKING TARGETING COMPUTER",
      "2 MAXIMUM HARDWARE",
      "3 MISSILES: " + (commander.unlimitedMissiles ? "UNLIMITED" : "NORMAL"),
      "4 FUEL: " + (commander.unlimitedFuel ? "UNLIMITED" : "NORMAL"),
      String(format: "5 JUMP LIMIT: %.1f LY", commander.maximumJumpDistance),
      "6 AUTO TRADE: " + (commander.autoTrade ? "ON" : "OFF"),
      "7 SPEECH: " + (commander.speech ? "ON" : "OFF"),
      "8 CARGO: " + (commander.unlimitedCargo ? "UNLIMITED" : "NORMAL"),
      String(format: "9 CASH: %.1f CR", Double(commander.credits) / 10),
      "A AUTO TARGET: " + (commander.autoTarget ? "ON" : "OFF"),
      "E AUTO ECM: " + (commander.autoECM ? "ON" : "OFF"),
      "B MILITARY RETURN FIRE: " + (commander.retaliationEnabled ? "ON" : "OFF"),
      "F FUEL SCOOPS: "
        + (commander.equipment.contains("Fuel Scoops") ? "FITTED" : "NOT FITTED"),
    ]
  }
}
