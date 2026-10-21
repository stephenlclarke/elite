local M = {}
function M.accepted(e,w,d)
  return {data={notifications=0,starts=0},commands={{op='child.ensure',id='patrol'}}}
end
function M.started(e,w,d)
  d.starts=d.starts+1
  d.child=w.children.patrol.instance
  return {data=d,commands={}}
end
function M.receipted(e,w,d)
  d.notifications=d.notifications+1
  d.proof=w.receipt_requirements['owned-report'].satisfied
  return {data=d,commands={}}
end
function M.contact(e,w,d)
  local commands={{op='child.ensure',id='patrol'}}
  if w.main_station and w.receipt_requirements['owned-report'].satisfied then
    commands[#commands+1]={op='dialogue.offer',id='debrief'}
  end
  return {data=d,commands=commands}
end
function M.confirm(e,w,d)
  return {data=d,commands={{op='dialogue.commit',id='debrief',token=e.token},
    {op='milestone.ensure',index=0},{op='mission.finish',outcome='complete'}}}
end
function M.abandoned(e,w,d)
  return {data=d,commands={{op='mission.finish',outcome='abandoned'}}}
end
return M
