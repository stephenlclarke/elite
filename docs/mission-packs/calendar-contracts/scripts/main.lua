local function at_destination(w)
  return w.docked and w.main_station and w.galaxy == w.contract.destination_galaxy
    and w.system == w.contract.destination_system
end

return {
  generate = function(e, w, d)
    local destinations = {}
    for _, place in ipairs(w.destinations) do
      if place.distance > 0 and place.distance <= 7 then
        destinations[#destinations + 1] = place
      end
    end
    local offers = {}
    if #destinations > 0 then
      for i = 1, 2 do
        local place = destinations[1 + ((w.offer_draws[1] + i - 1) % #destinations)]
        local tonnes = 1 + (w.offer_draws[i + 1] % 3)
        offers[i] = {
          key = "run-" .. i, title = place.name .. " sample run " .. i,
          briefing = "Carry " .. tonnes .. " tonnes of sealed samples to " .. place.name
            .. " main orbital station. A direct jump with sufficient fuel is required before acceptance."
            .. " You have 24 hours of commander calendar time, including launch and hyperspace travel after acceptance. Late delivery forfeits the deposit and earns no reward.",
          destination_galaxy = w.galaxy, destination_system = place.system,
          reward = 500 + 100 * tonnes, deposit = 100, failure_reward = 0,
          refund_on_failure = false, duration = 86400, parameters = {tonnes = tonnes}
        }
      end
    end
    return {data = {offers = offers}, commands = {}}
  end,
  accepted = function(e, w, d)
    assert(w.contract.distance_ly <= w.jump_range_ly,
      "Refuel or select a ship that can make this contract's direct jump.")
    return {data = d, commands = {
      {op = "payload.add", id = "collect-samples", key = "samples", amount = w.contract.parameters.tonnes},
      {op = "milestone.ensure", index = 0},
      {op = "journal.append", text = "Accepted an identified sample run with its frozen deposit, reward and deadline."}
    }}
  end,
  contact = function(e, w, d)
    if at_destination(w) then
      return {data = d, commands = {{op = "dialogue.offer", id = "deliver-samples"}}}
    end
    if w.docked and w.main_station and w.station_id == w.contract.station_id then
      return {data = d, commands = {{op = "dialogue.offer", id = "cancel-samples"}}}
    end
    return {data = d, commands = {}}
  end,
  confirm = function(e, w, d)
    local outcome
    if e.dialogue_id == "cancel-samples" then
      assert(w.docked and w.main_station and w.station_id == w.contract.station_id,
        "Return the samples to their original offering station before cancelling.")
      outcome = "abandoned"
    else
      assert(at_destination(w), "Bring this contract's samples to its actual destination station.")
      outcome = w.contract.deadline_passed and "failed" or "complete"
    end
    return {data = d, commands = {
      {op = "dialogue.commit", id = e.dialogue_id, token = e.token},
      {op = "payload.remove", id = "deliver-samples", key = "samples", amount = w.contract.parameters.tonnes},
      {op = "milestone.ensure", index = 1},
      {op = "journal.append", text = outcome == "complete" and "Samples delivered on time; agreed payment and deposit refund settled."
        or outcome == "failed" and "Late samples handed in; the agreed failure terms settled."
        or "Original samples returned at the offering station; accepted work cancelled and deposit forfeited."},
      {op = "mission.finish", outcome = outcome}
    }}
  end,
  expired = function(e, w, d)
    return {data = d, commands = {
      {op = "journal.append", text = "The sample-run deadline passed. Hand in the overdue samples at the original destination; the agreed failure terms apply."}
    }}
  end
}
