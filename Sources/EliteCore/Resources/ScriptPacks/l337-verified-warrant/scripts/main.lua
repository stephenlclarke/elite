return {
  generate = function(e, w, d)
    local offers = {}
    local c = w.commander
    if w.galaxy == 0 and w.system == 7 and w.main_station and c
      and c.jump_range_ly >= 3.364975176728651 and c.lasers.front
      and c.lasers.front.nominal_damage > 0 then
      offers[1] = {
        key = "renas-hostile", title = "Verified Renas warrant / L2 H0 / 1120 CR",
        briefing = "VOSS: Avenor -> Renas -> Avenor. One uniquely identified armed aggressor."
          .. " Actual player-attributed destruction and return report required. 0t, 0 berths,"
          .. " no deposit, untimed; fixed 1120 CR. Fuel and refuelling remain your responsibility.",
        destination_galaxy = 0, destination_system = 185,
        reward = 11200, deposit = 0, failure_reward = 0, refund_on_failure = false,
        duration = 0, parameters = {route = {7,185,7}, legs = 2, hazard = 0,
          encounter = "verified-hostile", actor = "warrant-target", receiver = "voss-report"}
      }
    end
    return {data = {offers = offers}, commands = {}}
  end,
  accepted = function(e, w, d)
    return {data = {}, commands = {
      {op = "milestone.ensure", index = 0},
      {op = "journal.append", text = "VOSS: Warrant accepted. Identify the unique Renas armed aggressor, then return the real destruction report. No deadline."}
    }}
  end,
  deploy = function(e, w, d)
    local commands = {}
    local cohort = w.encounters["verified-hostile"]
    if w.galaxy == 0 and w.system == 185 and not w.docked
      and (not cohort or not cohort.admitted) then
      commands = {{op = "encounter.ensure", id = "verified-hostile"}}
    end
    return {data = d, commands = commands}
  end,
  admitted = function(e, w, d)
    return {data = d, commands = {{op = "actor.intent", id = "attack-player",
      encounter = "verified-hostile", actor = "warrant-target", mode = "attack",
      target = "player", offset = {0,0,0}, speed = 1, tolerance = 10}}}
  end,
  destroyed = function(e, w, d)
    local commands = {}
    if e.encounter_id == "verified-hostile" and e.alias == "warrant-target" then
      if e.destroyed_by_player then
        commands = {{op = "milestone.ensure", index = 1},
          {op = "journal.append", text = "Actual attributed target destruction recorded. No warrant payment until Voss receives the report at Avenor."}}
      else
        commands = {{op = "journal.append", text = "The target was destroyed without player attribution. Warrant failed; no payment or clue."},
          {op = "mission.finish", outcome = "failed"}}
      end
    end
    return {data = d, commands = commands}
  end,
  contact = function(e, w, d)
    local commands = {}
    if w.galaxy == 0 and w.system == 7 and w.main_station then
      local encounter = w.encounters["verified-hostile"]
      local report = encounter and encounter.destroyed
      commands = {{op = "dialogue.offer", id = report and "voss-report" or "voss-withdraw"}}
    end
    return {data = d, commands = commands}
  end,
  confirm = function(e, w, d)
    local commands = {}
    if e.dialogue_id == "voss-report" and e.choice_id == "report-verified-target" then
      commands = {
        {op = "dialogue.commit", id = "voss-report", token = e.token, choice_id = e.choice_id},
        {op = "milestone.ensure", index = 2},
        {op = "mission.finish", outcome = "complete"}
      }
    elseif e.dialogue_id == "voss-withdraw" and e.choice_id == "withdraw-warrant" then
      commands = {
        {op = "dialogue.commit", id = "voss-withdraw", token = e.token, choice_id = e.choice_id},
        {op = "mission.finish", outcome = "abandoned"}
      }
    end
    return {data = d, commands = commands}
  end
}
