return {
  generate = function(e, w, d)
    local offers = {}
    for _, plan in ipairs(w.courier_plan) do
      local label = plan.variant == "data" and "Encrypted data" or "Sealed package"
      offers[#offers + 1] = {
        key = plan.key, title = "Difficulty " .. plan.difficulty .. " - " .. label .. " to " .. plan.name,
        briefing = "PROJECT ESTIMATES. Carry this unique consignment to " .. plan.name
          .. " main orbital station and confirm the Courier Receiving Officer handoff."
          .. " Reopening keeps these offers. A later scheduled refresh may list new jobs.",
        destination_galaxy = w.galaxy, destination_system = plan.destination,
        reward = plan.reward, deposit = 0, failure_reward = 0, refund_on_failure = false,
        duration = plan.duration, parameters = {difficulty = plan.difficulty, variant = plan.variant}
      }
    end
    return {data = {offers = offers}, commands = {}}
  end,
  accepted = function(e, w, d)
    return {data = d, commands = {
      {op = "milestone.ensure", index = 0},
      {op = "journal.append", text = "Collected one identified courier consignment. Native mission-time deadline started."},
      {op = "courier.issue", id = "issue-consignment"}
    }}
  end,
  contact = function(e, w, d)
    local commands = {}
    if w.docked and w.main_station then
      if w.galaxy == w.contract.destination_galaxy and w.system == w.contract.destination_system then
        commands = {{op = "dialogue.offer", id = "courier-delivery"}}
      elseif w.station_id == w.contract.station_id then
        commands = {{op = "dialogue.offer", id = "courier-abandon"}}
      end
    end
    return {data = d, commands = commands}
  end,
  confirm = function(e, w, d)
    if e.dialogue_id == "courier-delivery" then
      return {data = d, commands = {
        {op = "milestone.ensure", index = 1},
        {op = "journal.append", text = "Confirmed the actual receiving officer handoff. Paid the frozen reward once."},
        {op = "courier.deliver", id = "deliver-consignment"}
      }}
    end
    return {data = d, commands = {
      {op = "journal.append", text = "Explicitly abandoned the courier job with its origin dispatcher. Paid: 0 CR."},
      {op = "courier.abandon", id = "abandon-consignment"}
    }}
  end
}
