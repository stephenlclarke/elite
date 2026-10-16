local M = {}
function M.accepted(e,w,d)
  return {data={phase='launch'},commands={{op='milestone.ensure',index=0},
    {op='journal.append',text='Skirmish accepted. Launch at Lave to meet the assigned opponents.'}}}
end
function M.undocked(e,w,d)
  local commands={}
  if w.galaxy==0 and w.system==7 and d.phase~='report' then
    commands={{op='encounter.ensure',id='opponents'}}
  end
  return {data=d,commands=commands}
end
function M.admitted(e,w,d)
  d.phase='battle'
  return {data=d,commands={
    {op='actor.intent',id='lead-attack',encounter='opponents',actor='lead',mode='attack',target='player',offset={0,0,0},speed=0.5,tolerance=100},
    {op='actor.intent',id='wing-attack',encounter='opponents',actor='wing',mode='attack',target='player',offset={0,0,0},speed=0.5,tolerance=100}}}
end
function M.pending(e,w,d)
  return {data=d,commands={{op='journal.append',text='Deployment pending. Clear the flight area, then retry by returning to the station and launching again.'}}}
end
function M.destroyed(e,w,d)
  local commands={}
  if w.encounters.opponents and w.encounters.opponents.destroyed then
    d.phase='report'
    commands={{op='milestone.ensure',index=1},
      {op='journal.append',text='Both actual assigned opponents destroyed. Report at Lave orbital station.'}}
  end
  return {data=d,commands=commands}
end
function M.contact(e,w,d)
  local commands={}
  if d.phase=='report' and w.galaxy==0 and w.system==7 and w.main_station then
    commands={{op='dialogue.offer',id='report'}}
  end
  return {data=d,commands=commands}
end
function M.confirm(e,w,d)
  local commands={}
  if d.phase=='report' and e.dialogue_id=='report' and w.galaxy==0 and w.system==7 and w.main_station then
    d.phase='complete'
    commands={{op='dialogue.commit',id='report',token=e.token},
      {op='credits',id='skirmish-pay',amount=1000},
      {op='milestone.ensure',index=2},
      {op='journal.append',text='Skirmish report confirmed. Paid 100 credits.'},
      {op='mission.finish',outcome='complete'}}
  end
  return {data=d,commands=commands}
end
return M
