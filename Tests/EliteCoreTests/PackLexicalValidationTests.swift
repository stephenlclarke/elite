import Testing

@testable import EliteCore

struct PackLexicalValidationTests {
  @Test func localIdentifiersMatchDeclaredASCIIAlphabetAndLengthLimits() {
    let initial = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz")
    let subsequent = initial.union(Set("0123456789.-"))
    for code in UInt8(0)...UInt8(127) {
      let character = Character(String(UnicodeScalar(code)))
      let value = String(character)
      #expect(PackValidation.localID(value) == initial.contains(character))
      #expect(PackValidation.localID("A" + value) == subsequent.contains(character))
    }
    #expect(!PackValidation.localID(""))
    #expect(PackValidation.localID(String(repeating: "A", count: 80)))
    #expect(!PackValidation.localID(String(repeating: "A", count: 81)))
    #expect(PackValidation.localID("a" + String(repeating: ".", count: 79)))
    #expect(PackValidation.localID("Z" + String(repeating: "-", count: 79)))
    #expect(PackValidation.localID("a..--.-9"))
    #expect(!PackValidation.localID("a_b"))
  }

  @Test func localIdentifiersRejectUnicodeControlsAndTrailingLineEndings() {
    let invalid = [
      "é", "K", "Ａ", "А", "A\u{0301}", "A🚀", "A\u{00a0}", "A\u{0085}",
      "A\u{2028}", "A\u{2029}", "A\u{0000}", "A\u{007f}", "A\n", "A\r", "A\r\n",
      "A\nB", "\nA", "A\t", "A ",
    ]
    for value in invalid { #expect(!PackValidation.localID(value)) }
  }

  @Test func modelReferencesRespectExactPrefixesGrammarAndInstalledCatalogue() throws {
    for id in ["SH001", "SH128"] {
      try #require(ShipCatalogue.ship(id) != nil)
      #expect(ScriptNPCModel.referenceValid("catalogue:" + id))
    }
    for id in ["SH000", "SH999"] {
      try #require(ShipCatalogue.ship(id) == nil)
      #expect(!ScriptNPCModel.referenceValid("catalogue:" + id))
    }
    // Pack-local asset existence is checked by loading; references retain their lexical contract.
    for model in ["asset:hull", "asset:A0.-", "asset:NotInstalled.-9"] {
      #expect(ScriptNPCModel.referenceValid(model))
    }
    #expect(ScriptNPCModel.referenceValid("asset:a" + String(repeating: "x", count: 79)))
    let invalid = [
      "", "SH128", "Catalogue:SH128", "catalogue:sh128", "catalogue:SH12", "catalogue:SH0128",
      "catalogue:SH１２８", "catalogue:SH128\n", "catalogue:SH128\r\n", "catalogue:SH128\u{0000}",
      "asset:", "Asset:hull", "asset:_hull", "asset:hull_name", "asset:hull/name", "asset:é",
      "asset:hull\n", "asset:hull\u{2028}", "asset:a" + String(repeating: "x", count: 80),
    ]
    for model in invalid { #expect(!ScriptNPCModel.referenceValid(model)) }
  }
}
