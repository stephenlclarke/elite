import Foundation

/// Structural bounds precede Foundation's allocation of large saved arrays and dictionaries.
/// Foundation remains responsible for the complete JSON grammar, numbers and UTF-8 validation.
enum ScriptSaveJSONPreflight {
  static func validate(_ data: Data) throws {
    struct Container {
      let closing: UInt8
      var commas = 0
    }
    var stack: [Container] = []
    var quoted = false
    var escaped = false
    var stringBytes = 0
    for byte in data {
      if quoted {
        stringBytes += 1
        guard stringBytes <= 6 * 262144 else { throw SaveError.invalidCommander }
        if escaped {
          escaped = false
        } else if byte == 92 {
          escaped = true
        } else if byte == 34 {
          quoted = false
        }
        continue
      }
      switch byte {
      case 34:
        quoted = true
        escaped = false
        stringBytes = 0
      case 91, 123:
        guard stack.count < 96 else { throw SaveError.invalidCommander }
        stack.append(.init(closing: byte == 91 ? 93 : 125))
      case 93, 125:
        guard stack.last?.closing == byte else { throw SaveError.invalidCommander }
        stack.removeLast()
      case 44:
        guard !stack.isEmpty else { throw SaveError.invalidCommander }
        stack[stack.count - 1].commas += 1
        guard stack[stack.count - 1].commas < 16384 else { throw SaveError.invalidCommander }
      default: break
      }
    }
    guard !quoted, !escaped, stack.isEmpty else { throw SaveError.invalidCommander }
  }
}
