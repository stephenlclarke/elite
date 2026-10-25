enum ShowroomProfileGuide {
  static func rows(profileCount: Int) -> [String] {
    guard profileCount > 0 else { return ["NO SPECIFICATION PROFILE AVAILABLE"] }
    guard profileCount > 1 else { return ["ONE PROFILE; NO CYCLING"] }
    return [
      "COMMA / PERIOD - CHANGE PROFILE",
      "CLICK PREV / NEXT TO CHANGE PROFILE",
    ]
  }
}
