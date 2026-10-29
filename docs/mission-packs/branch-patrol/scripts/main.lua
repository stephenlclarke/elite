local M = {}
function M.accepted(e,w,d)
  return {data={phase='launch'},commands={{op='milestone.ensure',index=0},
    {op='journal.append',text='Patrol accepted. Launch at Lave to meet the assigned raiders.'}}}
end
function M.undocked(e,w,d)
  local commands={}
  if w.galaxy==0 and w.system==7 and d.phase~='report' then
    commands={{op='encounter.ensure',id='raiders'}}
  end
  return {data=d,commands=commands}
end
function M.admitted(e,w,d)
  d.phase='battle'
  return {data=d,commands={}}
end
function M.pending(e,w,d)
  return {data=d,commands={{op='journal.append',text='Deployment pending. Clear the flight area, then retry by returning to the station and launching again.'}}}
end
function M.destroyed(e,w,d)
  local commands={}
  if w.encounters.raiders and w.encounters.raiders.destroyed then
    d.phase='report'
    commands={{op='milestone.ensure',index=1},
      {op='journal.append',text='Both actual assigned raiders destroyed. Report at Lave orbital station.'}}
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
      {op='credits',id='patrol-pay',amount=1000},
      {op='milestone.ensure',index=2},
      {op='journal.append',text='Patrol report confirmed. Paid 100 credits.'},
      {op='mission.finish',outcome='complete'}}
  end
  return {data=d,commands=commands}
end
return M
