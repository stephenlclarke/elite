local credits = {500, 1500, 3000}
local food = {1, 3, 5}

return {
  generate = function(e, w, d)
    local offers = {}
    for _, variant in ipairs({"credits", "food"}) do
      for tier = 1, 3 do
        local charge = variant == "credits" and (credits[tier] .. ".0 CR")
          or (food[tier] .. (food[tier] == 1 and " tonne Food" or " tonnes Food"))
        offers[#offers + 1] = {
          key = variant .. "-" .. tier,
          title = "Station Aid / difficulty " .. tier .. " / " .. charge,
          briefing = "Voluntarily donate " .. charge .. " in one complete donation."
            .. " Receive one Station Aid standing point at this actual main orbital station."
            .. " No cash reward, journey or deadline. Back changes nothing."
            .. " Amounts and local standing are project estimates, not historical/server tuning.",
          destination_galaxy = w.galaxy, destination_system = w.system,
          reward = 0, deposit = 0, failure_reward = 0, refund_on_failure = false,
          duration = 0,
          parameters = {difficulty = tier, variant = variant, profile_seed = w.board_seed_u32}
        }
      end
    end
    return {data = {offers = offers}, commands = {}}
  end,
  accepted = function(e, w, d)
    return {data = d, commands = {
      {op = "milestone.ensure", index = 0},
      {op = "journal.append", text = "Donation completed once. Station Aid standing increased at this main station."},
      {op = "pledge.commit"}
    }}
  end
}
