return {
  generate = function(e, w, d)
    local offers = {}
    for _, plan in ipairs(w.freight_plan) do
      offers[#offers + 1] = {
        key = plan.key, title = "Supplied freight difficulty " .. plan.difficulty,
        briefing = "PROJECT ESTIMATES. Issuer supplies " .. plan.quantity
          .. " unique owned tonnes of the frozen commodity and deliver at main orbital system "
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
      {op = "journal.append", text = "Accepted issuer-owned freight. Unique units occupy real hold space; no acceptance fee charged."}
    }}
  end,
  contact = function(e, w, d)
    local commands = {}
    if w.docked and w.main_station then
      if w.galaxy == w.contract.destination_galaxy and w.system == w.contract.destination_system then
        commands = {{op = "dialogue.offer", id = "freight-delivery"}}
      elseif w.station_id == w.contract.station_id then
        commands = {{op = "dialogue.offer", id = "freight-abandon"}}
      end
    end
    return {data = d, commands = commands}
  end
}
