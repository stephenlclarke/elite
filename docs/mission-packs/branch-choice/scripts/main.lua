local M={}
function M.accepted(e,w,d)
  return {data=d,commands={{op='journal.append',text='Choose one assignment at Lave Mission Contacts.'}}}
end
function M.contact(e,w,d)
  local commands={}
  if w.galaxy==0 and w.system==7 and w.main_station and not w.choices.assignment then
    commands={{op='dialogue.offer',id='assignment'}}
  end
  return {data=d,commands=commands}
end
function M.confirm(e,w,d)
  local commands={}
  if e.dialogue_id=='assignment' and w.galaxy==0 and w.system==7 and w.main_station then
    commands={{op='dialogue.commit',id='assignment',token=e.token,choice_id=e.choice_id},
      {op='milestone.ensure',index=0},
      {op='journal.append',text='One assignment confirmed. Reopen Contacts to accept its separate mission.'},
      {op='mission.finish',outcome='complete'}}
  end
  return {data=d,commands=commands}
end
return M
