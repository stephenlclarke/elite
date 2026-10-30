return {
  generate = function(e, w, d)
    return {data = {offers = {{
      key = "credits-1",
      title = "Cedamar Orbital Relief Reserve / Donate 500.0 CR",
      briefing = "Voluntarily contribute 500.0 CR to the named Cedamar reserve."
        .. " No cash reward, refund, cargo, berth, deadline or privilege. Back changes nothing.",
      destination_galaxy = w.galaxy, destination_system = w.system,
      reward = 0, deposit = 0, failure_reward = 0, refund_on_failure = false,
      duration = 0,
      parameters = {difficulty = 1, variant = "credits", profile_seed = w.board_seed_u32}
    }}}, commands = {}}
  end,
  accepted = function(e, w, d)
    return {data = d, commands = {
      {op = "milestone.ensure", index = 0},
      {op = "journal.append", text = "The Cedamar Orbital Relief Reserve acknowledged this voluntary contribution. No cash reward or privilege."},
      {op = "pledge.commit"}
    }}
  end
}
