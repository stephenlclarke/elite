local mission = {}
function mission.accepted(event, world, data)
  return {data=data, commands={
    {op='passengers.board', id='board-charter', party='charter'},
    {op='milestone.ensure', index=0}
  }}
end
function mission.contact(event, world, data)
  if world.main_station and world.galaxy == 0 and world.system == 129 then
    return {data=data, commands={{op='dialogue.offer', id='delivery'}}}
  end
  return {data=data, commands={}}
end
function mission.confirm(event, world, data)
  return {data=data, commands={
    {op='dialogue.commit', id='delivery', token=event.token},
    {op='passengers.deliver', id='deliver-charter', party='charter'},
    {op='credits', id='charter-payment', amount=1000},
    {op='milestone.ensure', index=1},
    {op='mission.finish', outcome='complete'}
  }}
end
return mission
