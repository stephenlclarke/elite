local M={}
function M.accepted(e,w,d)
  return {data={contacts=0},commands={{op='journal.append',text='Reopen Lave Mission Contacts to receive the reference briefing.'}}}
end
function M.contact(e,w,d)
  d.contacts=d.contacts+1
  local commands={}
  if w.main_station and w.galaxy==0 and w.system==7 then commands={{op='dialogue.offer',id='briefing'}} end
  return {data=d,commands=commands}
end
function M.confirm(e,w,d)
  local commands={}
  if e.dialogue_id=='briefing' and w.main_station and w.galaxy==0 and w.system==7 then
    commands={{op='dialogue.commit',id='briefing',token=e.token},
      {op='book.unlock',id='field-notes'},
      {op='milestone.ensure',index=0},
      {op='journal.append',text='Station field notes received. Read them from Mission Library.'},
      {op='mission.finish',outcome='complete'}}
  end
  return {data=d,commands=commands}
end
return M
