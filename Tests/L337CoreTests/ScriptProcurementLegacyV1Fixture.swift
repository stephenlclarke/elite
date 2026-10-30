import Foundation

// Exact unreleased generator-1 content, retained independently of the current pack.
// This is a frozen source oracle, not a historical production save or default content.
enum ScriptProcurementLegacyV1Fixture {
  static let digest = "b5417a83aecf3f2c2b87b78c4c360719165330acdec4d05c0b5a47da831a4e59"
  static let manifest = #"""
    schemaVersion = 2
    missionAPI = 2
    id = "project.generated-procurement"
    version = "1.0.0"
    minimumEngine = "2.0.0"
    capabilities = ["script-lua-v1", "story-v2", "local-flight-clocks-v2", "contracts-basic-v2", "procurement-contracts-basic-v2", "mission-calendar-v2", "durable-commands-v2", "partial-collections-v2", "gallery-basic-v2"]
    priority = 565
    source = "PROJECT-SPACE-G03-1 procurement variant, approved project adaptation of S10/S18/D03/D04/O08 in generated-space-project-profiles.json. Quantities, payment, deadlines and generation are PROJECT ESTIMATES, not recovered live-server distributions. Supplied freight is not implemented by this pack."
    license = "MIT"
    environments = ["space", "orbital-station"]
    module = "scripts/main.lua"

    [mission]
    id = "procurement"
    title = "Procurement jobs"
    briefing = "Acquire the frozen Food, Textiles or Machinery requirement through ordinary trade, then deliver it at the named destination main station. Real partial lots are retained. Only the final native handoff pays. Estimates are project balance values."
    destination = "Frozen destination main orbital / Procurement Receiving Officer"
    reward = "Frozen tier base plus 300 CR per required hop, once after all goods are received. PROJECT ESTIMATES."
    milestones = ["Deliver the entire frozen native material requirement"]
    requiredCollections = ["procurement-goods"]

    [board]
    id = "procurement-jobs"
    title = "Procurement jobs / PROJECT ESTIMATES"
    generator = "generate"
    clock = "missionCalendar"
    refreshSeconds = 3600
    exclusiveGroup = "g03-procurement"

    [procurement]
    profile = "PROJECT-SPACE-G03-1"
    generatorRevision = 1
    variant = "procurement"
    deliveryContact = "procurement-delivery"
    abandonContact = "procurement-abandon"

    [procurement.collectionTemplate]
    id = "procurement-goods"
    title = "Requested procurement goods"

    [[dialogs]]
    id = "procurement-delivery"
    text = "Procurement Receiving Officer: confirm the displayed ordinary goods. Earlier partial receipts remain recorded. Only the entire frozen requirement earns its single payment. Back changes nothing."
    collection = "procurement-goods"

    [[dialogs]]
    id = "procurement-abandon"
    text = "Procurement Dispatch Officer: confirm abandonment for 0 CR. Earlier partial deliveries remain recorded; remaining ordinary cargo stays yours. Back changes nothing."

    [[handlers]]
    event = "mission.accepted"
    function = "accepted"
    [[handlers]]
    event = "contact.requested"
    function = "contact"
    [[handlers]]
    event = "dialogue.confirmed"
    function = "confirm"

    [trial]
    ship = "SH023"
    galaxy = 0
    system = 0
    credits = 100000
    cabins = 0
    flight = true
    offer = 0
    """# + "\n"

  static let module = #"""
    return {
      generate = function(e, w, d)
        local offers = {}
        for _, plan in ipairs(w.procurement_plan) do
          offers[#offers + 1] = {
            key = plan.key, title = "Procurement difficulty " .. plan.difficulty,
            briefing = "PROJECT ESTIMATES. Acquire " .. plan.quantity
              .. " tonnes of the frozen requested commodity and deliver at main orbital system "
              .. plan.destination .. ". Partial deliveries persist; only the final native Confirm pays.",
            destination_galaxy = w.galaxy, destination_system = plan.destination,
            reward = plan.reward, deposit = 0, failure_reward = 0, refund_on_failure = false,
            duration = plan.duration, parameters = plan.parameters
          }
        end
        return {data = {offers = offers}, commands = {}}
      end,
      accepted = function(e, w, d)
        return {data = d, commands = {
          {op = "collection.ensure", id = "procurement-goods"},
          {op = "journal.append", text = "Accepted the frozen procurement requirement. No goods issued and no acceptance fee charged."}
        }}
      end,
      contact = function(e, w, d)
        local commands = {}
        if w.docked and w.main_station then
          if w.galaxy == w.contract.destination_galaxy and w.system == w.contract.destination_system then
            commands = {{op = "dialogue.offer", id = "procurement-delivery"}}
          elseif w.station_id == w.contract.station_id then
            commands = {{op = "dialogue.offer", id = "procurement-abandon"}}
          end
        end
        return {data = d, commands = commands}
      end,
      confirm = function(e, w, d)
        local commands = {}
        if e.dialogue_id == "procurement-delivery" then
          commands = {{op = "collection.deliver", id = "procurement-goods", token = e.token}}
        end
        return {data = d, commands = commands}
      end
    }
    """# + "\n"

  static func write(to directory: URL) throws {
    let scripts = directory.appendingPathComponent("scripts")
    try FileManager.default.createDirectory(at: scripts, withIntermediateDirectories: true)
    try Data(manifest.utf8).write(to: directory.appendingPathComponent("manifest.toml"))
    try Data(module.utf8).write(to: scripts.appendingPathComponent("main.lua"))
  }
}
