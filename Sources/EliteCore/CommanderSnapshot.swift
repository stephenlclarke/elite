/// Immutable review input; sharing its storage never shares mutable simulation state.
final class CommanderSnapshot: Sendable {
  let value: Commander

  init(_ value: Commander) {
    self.value = value
  }
}
