local M={}
local function atContact(w)
  return w.main_station and w.galaxy==0 and w.system==7
end
function M.accepted(e,w,d)
  return {data=d,commands={{op='journal.append',text='Visit Lave Mission Contacts. Deferring leaves the decision available.'}}}
end
function M.contact(e,w,d)
  local commands={}
  if atContact(w) then commands={{op='dialogue.offer',id='decision'}} end
  return {data=d,commands=commands}
end
function M.confirm(e,w,d)
  local commands={}
  if e.dialogue_id=='decision' and atContact(w) then
    commands={{op='dialogue.commit',id='decision',token=e.token,choice_id=e.choice_id}}
    local answers=w.answers.decision or {}
    if e.choice_id=='proceed' and answers.details and answers.details.count>=1 then
      commands[#commands+1]={op='milestone.ensure',index=0}
      commands[#commands+1]={op='journal.append',text='The genuine Details and Proceed answers are recorded. No payment is due.'}
      commands[#commands+1]={op='mission.finish',outcome='complete'}
    else
      local text='Decision deferred. You can choose again or leave with Back.'
      if e.choice_id=='details' then text='The station has supplied the information. Choose Proceed when ready.' end
      if e.choice_id=='proceed' then text='Ask for Details before proceeding.' end
      commands[#commands+1]={op='journal.append',text=text}
      commands[#commands+1]={op='dialogue.offer',id='decision'}
    end
  end
  return {data=d,commands=commands}
end
return M
