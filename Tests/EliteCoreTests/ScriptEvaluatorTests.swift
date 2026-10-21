import Foundation
import Testing

@testable import EliteCore

private func runScript(
  _ body: String, state: ScriptValue = .object([:]),
  limits: ScriptLimits = ScriptLimits()
) throws -> ScriptEvaluation {
  try ScriptEvaluator.evaluate(
    source: Data(body.utf8), handler: "on_event", event: .object(["kind": .string("test")]),
    snapshot: .object(["credits": .integer(1000)]), state: state, limits: limits)
}

@Test func luaExecutesProceduresAndExplicitDataWithoutHiddenState() throws {
  let source = """
    local hidden = 0
    local function reward(n) return n * 2 end
    return {on_event = function(event, world, data)
      hidden = hidden + 1
      data.counter = (data.counter or 0) + hidden
      return {data = data, commands = {{op = "credits", amount = reward(world.credits)}}}
    end}
    """
  let first = try runScript(source)
  let second = try runScript(source, state: first.data)
  #expect(first.data["counter"] == .integer(1))
  #expect(second.data["counter"] == .integer(2))
  #expect(first.commands.first?["amount"] == .integer(2000))
  #expect(first.peakHeapBytes > 0)
}

@Test func luaPreservesSignedIntegerLimitsAndRejectsInvalidOutput() throws {
  let value: ScriptValue = .object([
    "min": .integer(.min), "max": .integer(.max), "utf8": .string("Café"),
  ])
  let output = try runScript(
    "return {on_event=function(e,w,d) return {data=d,commands={}} end}", state: value)
  #expect(output.data == value && output.commands.isEmpty)
  for source in [
    "return {on_event=function() return {data={x=0/0},commands={}} end}",
    "return {on_event=function() local x={} x.self=x return {data=x,commands={}} end}",
    "return {on_event=function() return {data={x=function() end},commands={}} end}",
    "return {on_event=function() return {data={},commands={[2]={op='x'}}} end}",
    "return {on_event=function() return {data={},commands={},unexpected=true} end}",
    "return {on_event=function() return {data={x=tostring({})},commands={}} end}",
    "return {}", "syntax error", "return 1",
  ] { #expect(throws: MissionPackError.self) { try runScript(source) } }
}

@Test func luaContainsLoopsAllocationRecursionAndCompilerBudgets() throws {
  for source in [
    "while true do end",
    "return {on_event=function() while true do end end}",
    "return {on_event=function() local a={} for i=1,100000 do a[i]={i,i,i,i} end end}",
    "return {on_event=function() local function f() return 1+f() end return f() end}",
    "return {on_event=function() error('expected fault') end}",
  ] { #expect(throws: MissionPackError.self) { try runScript(source) } }
  var limits = ScriptLimits()
  limits.heapBytes = 65536
  limits.allocationBytes = 65536
  #expect(throws: MissionPackError.self) {
    try runScript(
      "return {on_event=function() local a={} for i=1,5000 do a[i]={i} end end}", limits: limits)
  }
  limits = ScriptLimits()
  limits.outputBytes = 32
  #expect(throws: MissionPackError.self) {
    try runScript(
      "return {on_event=function() return {data={long='abcdefghijklmnopqrstuvwxyz'},commands={}} end}",
      limits: limits)
  }
}

@Test func luaSandboxHasNoExternalOrBudgetCatchingFacilities() throws {
  let result = try runScript(
    """
    return {on_event=function(e,w,d)
      assert(os == nil and io == nil and package == nil and debug == nil)
      assert(require == nil and load == nil and loadfile == nil and dofile == nil)
      assert(pcall == nil and xpcall == nil and coroutine == nil and setmetatable == nil)
      assert(math.random == nil and math.randomseed == nil and pairs == nil and next == nil)
      return {data={ok=true, scalar=tostring(123)},commands={}}
    end}
    """)
  #expect(result.data["ok"] == .bool(true))
  #expect(result.data["scalar"] == .string("123"))
}

@Test func wireRejectsMalformedAndOversizedData() throws {
  let value: ScriptValue = .object([
    "a": .array([.null, .bool(true), .number(1.5)]), "z": .string("ok"),
  ])
  #expect(try ScriptWire.decode(ScriptWire.encode([value])) == value)
  #expect(throws: MissionPackError.self) { try ScriptWire.decode(Data([5, 255, 255, 255, 255])) }
  #expect(throws: MissionPackError.self) { try ScriptWire.decode(Data([255])) }
  #expect(throws: MissionPackError.self) { try ScriptWire.decode(Data([0, 0])) }
  #expect(throws: MissionPackError.self) { try ScriptWire.encode([.number(.infinity)]) }
  #expect(throws: MissionPackError.self) { try ScriptWire.encode([.string("large")], limit: 2) }
  var deep: ScriptValue = .null
  for _ in 0..<35 { deep = .array([deep]) }
  #expect(throws: MissionPackError.self) { try ScriptWire.encode([deep]) }
}

@Test func nativeLeakDiagnosticExercisesInterpreterSuccessAndAbortLifetimes() async throws {
  try await GameRuntime().diagnoseScriptHost()
}
