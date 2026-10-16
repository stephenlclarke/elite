local M={}
function M.accepted(e,w,d)
  return {data={reports=0},commands={{op='journal.append',
    text='Accept and fly the separate patrol. This debrief waits for its genuine reported completion.'}}}
end
function M.receipted(e,w,d)
  d.reports=d.reports+1
  return {data=d,commands={{op='journal.append',text='The native patrol report has arrived. Visit Lave Mission Contacts.'}}}
end
function M.contact(e,w,d)
  local commands={}
  if w.receipt_requirements['patrol-report'].satisfied and w.commander.location.main_station
    and w.commander.location.galaxy==0 and w.commander.location.system==7 then
    commands={{op='dialogue.offer',id='debrief'}}
  end
  return {data=d,commands=commands}
end
function M.confirm(e,w,d)
  local commands={}
  if e.dialogue_id=='debrief' and w.commander.location.main_station
    and w.commander.location.galaxy==0 and w.commander.location.system==7 then
    commands={{op='dialogue.commit',id='debrief',token=e.token},
      {op='milestone.ensure',index=0},
      {op='journal.append',text='Genuine patrol completion joined; debrief closed without additional payment.'},
      {op='mission.finish',outcome='complete'}}
  end
  return {data=d,commands=commands}
end
return M
