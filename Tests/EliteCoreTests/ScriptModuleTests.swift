import Foundation
import Testing

@testable import EliteCore

private struct ModuleFixture {
  let root: URL
  init(main: String, modules: [String: String], declarations: String? = nil) throws {
    root = FileManager.default.temporaryDirectory.appendingPathComponent(
      "modules-" + UUID().uuidString)
    try FileManager.default.createDirectory(
      at: root.appendingPathComponent("scripts"), withIntermediateDirectories: true)
    let base = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/mission-packs/scripted-courier/manifest.toml")
    var manifest = try String(contentsOf: base, encoding: .utf8)
    manifest = manifest.replacingOccurrences(
      of: "capabilities = [", with: "capabilities = [\"pack-modules-v2\", ")
    if let declarations {
      manifest += declarations
    } else {
      for id in modules.keys.sorted() {
        manifest += "\n[[modules]]\nid=\"\(id)\"\npath=\"scripts/\(id).lua\"\n"
      }
    }
    try manifest.write(
      to: root.appendingPathComponent("manifest.toml"), atomically: true, encoding: .utf8)
    try main.write(
      to: root.appendingPathComponent("scripts/main.lua"), atomically: true, encoding: .utf8)
    for (id, source) in modules {
      try source.write(
        to: root.appendingPathComponent("scripts/\(id).lua"), atomically: true, encoding: .utf8)
    }
  }
  func clean() { try? FileManager.default.removeItem(at: root) }
}
private let emptyModuleHandlers = """
  local function empty(e,w,d) return {data=d,commands={}} end
  return {accepted=empty,contact=empty,confirm=empty}
  """

@Test func reusableLuaModulesImportLazilyCacheWithinDispatchAndResetAcrossDispatches() throws {
  let fixture = try ModuleFixture(
    main: """
      local a=require('alpha')
      local b=require('alpha')
      assert(a==b)
      local function run(e,w,d)
        a.count=a.count+1
        d.total=(d.total or 0)+a.calculate()
        d.ephemeral=a.count
        return {data=d,commands={}}
      end
      return {accepted=run,contact=run,confirm=run}
      """,
    modules: [
      "alpha": "local z=require('zeta'); return {count=0,calculate=z.calculate}",
      "zeta": "return {calculate=function() return 7 end}",
    ])
  defer { fixture.clean() }
  let pack = try ScriptPackLibrary.read(fixture.root)
  let first = try ScriptEvaluator.evaluate(
    source: pack.source, handler: "accepted", event: .object([:]), snapshot: .object([:]),
    state: .object([:]))
  let second = try ScriptEvaluator.evaluate(
    source: pack.source, handler: "contact", event: .object([:]), snapshot: .object([:]),
    state: first.data)
  #expect(first.data["total"] == .integer(7) && second.data["total"] == .integer(14))
  #expect(first.data["ephemeral"] == .integer(1) && second.data["ephemeral"] == .integer(1))
  #expect(pack.resourceBytes.count == 2 && pack.entryBytes != pack.source)
}

@Test func moduleInstallationRetainsExactAuthoredFilesAndDigestIncludesEveryHelper() throws {
  let fixture = try ModuleFixture(
    main: "return require('helper')", modules: ["helper": emptyModuleHandlers])
  defer { fixture.clean() }
  let pack = try ScriptPackLibrary.read(fixture.root)
  let library = fixture.root.appendingPathComponent("library")
  let installed = try ScriptPackLibrary.install(pack, directory: library)
  #expect(
    try Data(contentsOf: installed.appendingPathComponent("scripts/main.lua")) == pack.entryBytes)
  #expect(
    try Data(contentsOf: installed.appendingPathComponent("scripts/helper.lua"))
      == pack.resourceBytes["scripts/helper.lua"])
  let reread = try ScriptPackLibrary.read(installed)
  #expect(reread.digest == pack.digest && reread.source == pack.source)
  try (emptyModuleHandlers + "\n-- changed exact bytes\n").write(
    to: fixture.root.appendingPathComponent("scripts/helper.lua"), atomically: true, encoding: .utf8
  )
  let changed = try ScriptPackLibrary.read(fixture.root)
  #expect(changed.digest != pack.digest)
  let other = try ScriptPackLibrary.install(changed, directory: library)
  let original = try ScriptPackLibrary.read(installed)
  #expect(other != installed && original.digest == pack.digest)
}

@Test func missingCyclicInvalidAndNonTableModulesFailWithinTheSameProtectedVm() throws {
  let cases: [(String, [String: String])] = [
    ("return require('missing')", ["helper": emptyModuleHandlers]),
    ("return require('a')", ["a": "return require('b')", "b": "return require('a')"]),
    ("return require('helper')", ["helper": "return 2"]),
    ("return require({})", ["helper": emptyModuleHandlers]),
    (emptyModuleHandlers, ["unused": "this is invalid Lua"]),
    ("return require('helper')", ["helper": "while true do end"]),
  ]
  for (main, modules) in cases {
    let fixture = try ModuleFixture(main: main, modules: modules)
    defer { fixture.clean() }
    #expect(throws: (any Error).self) { try ScriptPackLibrary.read(fixture.root) }
  }
}

@Test func importedModulesRetainSandboxRestrictionsAndNativeQuotaFailuresCannotBeCaught() throws {
  let helper = """
    assert(os==nil and io==nil and package==nil and load==nil and debug==nil)
    assert(pcall==nil and xpcall==nil and math.random==nil)
    local function accepted(e,w,d)
      while true do end
    end
    local function empty(e,w,d) return {data=d,commands={}} end
    return {accepted=accepted,contact=empty,confirm=empty}
    """
  let fixture = try ModuleFixture(main: "return require('helper')", modules: ["helper": helper])
  defer { fixture.clean() }
  let pack = try ScriptPackLibrary.read(fixture.root)
  var game = Game(executive: false)
  game.scriptPacks = [pack]
  let before = game.commander
  #expect(throws: (any Error).self) { try game.acceptScriptMission(pack) }
  #expect(game.commander == before && game.commander.scriptState.instances.isEmpty)
}

@Test func moduleDeclarationsRejectTraversalAliasesDuplicatePathsUnknownKeysAndMissingCapability()
  throws
{
  for declaration in [
    "\n[[modules]]\nid='helper'\npath='../secret.lua'\n",
    "\n[[modules]]\nid='helper'\npath='scripts/main.lua'\n",
    "\n[[modules]]\nid='helper'\npath='scripts/helper.lua'\nunknown=true\n",
    "\n[[modules]]\nid='helper'\npath='scripts/helper.lua'\n[[modules]]\nid='helper'\npath='scripts/other.lua'\n",
    "\n[[modules]]\nid='helper'\npath='scripts/helper.lua'\n[[modules]]\nid='other'\npath='scripts/helper.lua'\n",
  ] {
    let fixture = try ModuleFixture(
      main: emptyModuleHandlers, modules: ["helper": "return {}"], declarations: declaration)
    defer { fixture.clean() }
    #expect(throws: (any Error).self) { try ScriptPackLibrary.read(fixture.root) }
  }
  let fixture = try ModuleFixture(
    main: "return require('helper')", modules: ["helper": emptyModuleHandlers])
  defer { fixture.clean() }
  let manifest = fixture.root.appendingPathComponent("manifest.toml")
  let text = try String(contentsOf: manifest, encoding: .utf8).replacingOccurrences(
    of: "\"pack-modules-v2\", ", with: "")
  try text.write(to: manifest, atomically: true, encoding: .utf8)
  #expect(throws: (any Error).self) { try ScriptPackLibrary.read(fixture.root) }
}

@Test func moduleByteBudgetsAndLinkedResourcesAreRefusedBeforeInstallation() throws {
  let fixture = try ModuleFixture(
    main: "return require('helper')", modules: ["helper": emptyModuleHandlers])
  defer { fixture.clean() }
  let helper = fixture.root.appendingPathComponent("scripts/helper.lua")
  try Data(repeating: 32, count: 262144).write(to: helper)
  #expect(throws: (any Error).self) { try ScriptPackLibrary.read(fixture.root) }
  try Data([0]).write(to: helper)
  #expect(throws: (any Error).self) { try ScriptPackLibrary.read(fixture.root) }
  try FileManager.default.removeItem(at: helper)
  let elsewhere = fixture.root.appendingPathComponent("elsewhere.lua")
  try emptyModuleHandlers.write(to: elsewhere, atomically: true, encoding: .utf8)
  try FileManager.default.createSymbolicLink(at: helper, withDestinationURL: elsewhere)
  #expect(throws: (any Error).self) { try ScriptPackLibrary.read(fixture.root) }
}
