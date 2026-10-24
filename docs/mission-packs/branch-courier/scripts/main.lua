-- New content requires no Swift mission class. Native authority validates each proposal.
local M = {}
function M.accepted(event, world, data)
  data.phase = "carrying"
  return {data=data, commands={
    {op="payload.add", id="pickup", key="supplies", amount=1},
    {op="milestone.ensure", index=0},
    {op="journal.append", text="Sealed supplies collected. Deliver to Zaonce's orbital station."}
  }}
end
function M.contact(event, world, data)
  local commands = {}
  if data.phase == "carrying" and world.galaxy == 0 and world.system == 129 and world.main_station then
    commands[1] = {op="dialogue.offer", id="delivery"}
  end
  return {data=data, commands=commands}
end
function M.confirm(event, world, data)
  local commands = {}
  if data.phase == "carrying" and event.dialogue_id == "delivery" and world.galaxy == 0 and world.system == 129 and world.main_station then
    data.phase = "delivered"
    commands = {
      {op="dialogue.commit", id="delivery", token=event.token},
      {op="payload.remove", id="delivery-parcel", key="supplies", amount=1},
      {op="credits", id="delivery-pay", amount=500},
      {op="milestone.ensure", index=1},
      {op="journal.append", text="Supplies delivered at Zaonce orbital station. Paid 50 credits."},
      {op="mission.finish", outcome="complete"}
    }
  end
  return {data=data, commands=commands}
end
return M
