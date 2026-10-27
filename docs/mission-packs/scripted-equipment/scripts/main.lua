local function at_destination(world)
  return world.docked and world.main_station and world.galaxy == 0 and world.system == 153
end

return {
  accepted = function(event, world, data)
    return {data = data, commands = {
      {op = "gear.issue", id = "borrow-kit", gear = "ecm-kit", fit = true},
      {op = "milestone.ensure", index = 0},
      {op = "journal.append", text = "Borrowed an identified ECM unit. Return this original unit at Bevitha orbital station."}
    }}
  end,
  contact = function(event, world, data)
    if at_destination(world) and world.issued_equipment["ecm-kit"].status == "issued" then
      return {data = data, commands = {{op = "dialogue.offer", id = "return-kit"}}}
    end
    return {data = data, commands = {}}
  end,
  confirm = function(event, world, data)
    assert(at_destination(world), "Bring the original unit to Bevitha orbital station.")
    return {data = data, commands = {
      {op = "dialogue.commit", id = "return-kit", token = event.token},
      {op = "gear.return", id = "return-original-kit", gear = "ecm-kit"},
      {op = "credits", id = "loan-reward", amount = 500},
      {op = "milestone.ensure", index = 1},
      {op = "journal.append", text = "The original loan was returned at Bevitha orbital station; 50 credits paid."},
      {op = "mission.finish", outcome = "complete"}
    }}
  end
}
