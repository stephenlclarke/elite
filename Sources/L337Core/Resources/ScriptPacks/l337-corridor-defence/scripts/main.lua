local encounter = "registered-corridor"
local actors = {"raider-a", "raider-b", "raider-c"}
return {
  generate = function(e,w,d)
    local offers = {}
    local c = w.commander
    if w.galaxy == 0 and w.system == 7 and w.main_station and c
      and c.jump_range_ly >= 3.364975176728651 and c.lasers.front
      and c.lasers.front.nominal_damage > 0 then
      offers[1] = {key="renas-corridor", title="Registered corridor defence / L2 H0 / 1400 CR",
        briefing="VOSS: Avenor -> Renas -> Avenor. Three distinct registered armed raiders."
          .. " Actual player-attributed destruction of all three and return report required."
          .. " EMP disable, culling and unrelated kills do not count. 0t, 0 berths, no deposit,"
          .. " untimed; fixed 1400 CR. Fuel remains your responsibility.",
        destination_galaxy=0, destination_system=185, reward=14000, deposit=0,
        failure_reward=0, refund_on_failure=false, duration=0,
        parameters={route={7,185,7},legs=2,hazard=0,encounter=encounter,
          actors=actors,receiver="voss-corridor-report"}}
    end
    return {data={offers=offers},commands={}}
  end,
  accepted = function(e,w,d)
    return {data={},commands={{op="milestone.ensure",index=0},
      {op="journal.append",text="Registered corridor progress"}}}
  end,
  deploy = function(e,w,d)
    local cohort=w.encounters[encounter]
    local commands={}
    if w.galaxy==0 and w.system==185 and not w.docked and (not cohort or not cohort.admitted) then
      commands={{op="encounter.ensure",id=encounter}}
    end
    return {data=d,commands=commands}
  end,
  admitted = function(e,w,d)
    local commands={}
    for _,actor in ipairs(actors) do
      commands[#commands+1]={op="actor.intent",id="attack-"..actor,encounter=encounter,
        actor=actor,mode="attack",target="player",offset={0,0,0},speed=1,tolerance=10}
    end
    return {data=d,commands=commands}
  end,
  destroyed = function(e,w,d)
    local commands={}
    if e.encounter_id==encounter then
      commands={{op="journal.append",text="Registered corridor progress"}}
      if not e.destroyed_by_player then
        commands[#commands+1]={op="mission.finish",outcome="failed"}
      elseif w.encounters[encounter] and w.encounters[encounter].destroyed then
        commands[#commands+1]={op="milestone.ensure",index=1}
      end
    end
    return {data=d,commands=commands}
  end,
  contact = function(e,w,d)
    local commands={}
    if w.galaxy==0 and w.system==7 and w.main_station then
      local cohort=w.encounters[encounter]
      local report=cohort and cohort.destroyed
      commands={{op="journal.append",text="Registered corridor progress"},
        {op="dialogue.offer",id=report and "voss-corridor-report" or "voss-corridor-progress"}}
    end
    return {data=d,commands=commands}
  end,
  confirm = function(e,w,d)
    local commands={}
    if e.dialogue_id=="voss-corridor-report" and e.choice_id=="report-defended-corridor" then
      commands={{op="dialogue.commit",id=e.dialogue_id,token=e.token,choice_id=e.choice_id},
        {op="milestone.ensure",index=2},{op="mission.finish",outcome="complete"}}
    elseif e.dialogue_id=="voss-corridor-progress" then
      commands={{op="dialogue.commit",id=e.dialogue_id,token=e.token,choice_id=e.choice_id},
        {op="journal.append",text="Registered corridor progress"}}
      if e.choice_id=="review-withdrawal" then
        commands[#commands+1]={op="dialogue.offer",id="voss-corridor-withdraw"}
      end
    elseif e.dialogue_id=="voss-corridor-withdraw" and e.choice_id=="withdraw-corridor" then
      commands={{op="dialogue.commit",id=e.dialogue_id,token=e.token,choice_id=e.choice_id},
        {op="mission.finish",outcome="abandoned"}}
    end
    return {data=d,commands=commands}
  end
}
