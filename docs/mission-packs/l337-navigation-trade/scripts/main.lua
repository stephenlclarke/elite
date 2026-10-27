local M = {}
function M.accepted(e,w,d)
  return {data={},commands={{op='journal.append',text='Select a reachable original-world destination and legal tonne commodity, then reopen Mission Contacts to confirm fitting and the real trade plan.'}}}
end
function M.contact(e,w,d)
  local stage=w.navigation_trade.stage
  local id='progress'
  if stage=='unconfirmed' then id='fit'
  elseif stage=='sold' then id='receive'
  elseif stage=='lost' then id='lost' end
  return {data=d,commands={{op='dialogue.offer',id=id}}}
end
function M.confirm(e,w,d)
  local commands={{op='dialogue.commit',id=e.dialogue_id,token=e.token,choice_id=e.choice_id}}
  if e.dialogue_id=='fit' then
    commands[#commands+1]={op='training.trade.begin'}
    commands[#commands+1]={op='milestone.ensure',index=0}
    commands[#commands+1]={op='journal.append',text='Buy the quoted tonne through the actual market, fly the selected route and sell that tonne at its selected destination. Return here for training reception. No tutorial reward or profitable sale is invented.'}
  elseif e.choice_id=='cancel' then
    commands[#commands+1]={op='training.trade.cancel'}
    commands[#commands+1]={op='mission.finish',outcome='abandoned'}
  elseif e.dialogue_id=='receive' and e.choice_id=='receive' then
    commands[#commands+1]={op='training.trade.receive'}
    commands[#commands+1]={op='milestone.ensure',index=1}
    commands[#commands+1]={op='milestone.ensure',index=2}
    commands[#commands+1]={op='journal.append',text='The actual selected trade, fuel accounting and training reception are retained. One older curved signature is preserved in your journal for the AI at PLUGH.'}
    commands[#commands+1]={op='mission.finish',outcome='complete'}
  elseif e.dialogue_id=='lost' then
    commands[#commands+1]={op='training.trade.acknowledge-loss'}
    commands[#commands+1]={op='mission.finish',outcome='failed'}
  end
  return {data=d,commands=commands}
end
return M
