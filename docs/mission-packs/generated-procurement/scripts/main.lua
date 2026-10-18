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
