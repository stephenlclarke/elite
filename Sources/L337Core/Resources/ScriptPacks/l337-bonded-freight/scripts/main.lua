return {
  generate = function(e, w, d)
    local offers = {}
    for _, plan in ipairs(w.freight_plan) do
      offers[#offers + 1] = {
        key = plan.key,
        title = "Bonded machinery / premium H" .. plan.hazard_tier,
        briefing = "TOREN supplies " .. plan.quantity
          .. " original machinery tonnes. The full frozen route has " .. plan.route_legs
          .. " leg(s), with declared pricing tier H" .. plan.hazard_tier
          .. "; this is not a route-safety guarantee. Quoted reward " .. (plan.reward / 10)
          .. " CR, plus return of the separate " .. (plan.deposit / 10)
          .. " CR bond at complete native workshop reception. No deadline. Back transfers nothing.",
        destination_galaxy = w.galaxy,
        destination_system = plan.destination,
        reward = plan.reward,
        deposit = plan.deposit,
        failure_reward = 0,
        refund_on_failure = false,
        duration = plan.duration,
        parameters = plan.parameters
      }
    end
    return {data = {offers = offers}, commands = {}}
  end,
  accepted = function(e, w, d)
    return {data = d, commands = {
      {op = "journal.append", text = "TOREN: The three original machinery tonnes are aboard and the 75 CR bond is held. It returns only with successful custody, never through intermediate docking. Keep the actual consignment and its named workshop endpoint. No deadline."}
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
