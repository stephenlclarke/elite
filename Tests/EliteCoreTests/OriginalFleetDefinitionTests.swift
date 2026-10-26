import Testing

@testable import EliteCore

struct OriginalFleetDefinitionTests {
  @Test func stagedDefinitionsPreserveKnownCurrentOriginalValuesAndConflicts() throws {
    let definitions = OriginalFleetDefinitionData.staged
    #expect(definitions.count == 171)
    #expect(Set(definitions.map(\.id)).count == 171)
    let optionalMule = definitions.first { $0.id == "SH001" }
    let mule = try #require(optionalMule)
    #expect(mule.name == "Mule" && mule.family == "mule")
    #expect(mule.nativePerformance?.cargo == 64)
    #expect(mule.nativePerformance?.speed == 34.8)
    #expect(mule.authored["playerFlyable"] == .boolean(true))
    let conflicts = definitions.filter { $0.nativePerformance?.valid == false }.map(\.id)
    #expect(conflicts == ["SH040", "SH043", "SH081", "SH123"])
    let optionalMedusa = definitions.first { $0.id == "SH171" }
    let medusa = try #require(optionalMedusa)
    #expect(medusa.purchasePolicy == "plughQuestFabrication")
    #expect(
      definitions.filter(\.runtimeReady).map(\.id) == [
        "SH002", "SH003", "SH004", "SH007", "SH012", "SH018", "SH019", "SH027", "SH029", "SH030",
        "SH031", "SH032", "SH033", "SH035", "SH036", "SH041", "SH042", "SH043", "SH044", "SH045",
        "SH046",
        "SH047", "SH054", "SH055", "SH057", "SH059", "SH061", "SH062", "SH064", "SH065", "SH068",
        "SH069", "SH070", "SH074", "SH075", "SH077", "SH078", "SH079",
      ])
  }
}
