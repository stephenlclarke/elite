local cues = {
  ["offer"] = "Crimbo Dispatch: One relay, one tonne, and a short trip to Atisen. Fly alongside Santa to calibrate it, then deliver it to their orbital station. Full calibration pays 3,000 credits; urgent dispatch pays 1,500. Interested?",
  ["accepted"] = "Crimbo Dispatch: Relay secured. Find Santa on the orbital route and request the dispatch manifest. Keep your weapons safe: the Rudolfs take their work seriously.",
  ["hello"] = "Santa: Dispatch sent you? Good. Hold within five kilometres while we sign the manifest. Presents are easy. Paperwork is the real cargo.",
  ["calibrate"] = "Santa: Manifest signed. Stay within eight kilometres while we make eighteen kilometres of route. Your relay has three lights to collect. There's no prize for bumping the sleigh.",
  ["checkpoint1"] = "Relay: First calibration light confirmed.",
  ["checkpoint2"] = "Relay: Second calibration light confirmed.",
  ["checkpoint3"] = "Relay: Third calibration light confirmed.",
  ["full-ready"] = "Santa: All lights green and the timing checks out. Take that relay to Atisen's orbital dispatch desk. Safe passage, Commander.",
  ["urgent-choice"] = "Dispatch: Send the signed relay without full calibration? Delivery pays 1,500 credits. You can keep calibrating instead.",
  ["disabled"] = "Dispatch: Santa's drive is offline. Your held relay is safe. Wait for this ship to recover, use an already authenticated manifest for urgent delivery, or recover the original crew or computer core.",
  ["lost-santa"] = "Dispatch: We've lost Santa's ship. An already authenticated manifest still permits urgent dispatch. Otherwise recover the original computer core or bring a surviving crew member safely to Crimbo. If neither is possible, return the relay.",
  ["rescue"] = "Crimbo Welfare: Crew identity confirmed and safe handover recorded. Your 500-credit crew commendation was transferred.",
  ["recovery-ready"] = "Dispatch: Recovered manifest authenticated. Atisen will accept the relay. Recovery delivery pays 2,000 credits.",
  ["complete-full"] = "Atisen Dispatch: Relay received, all three checks verified. 3,000 credits transferred. Crimbo's next delivery has a guiding light.",
  ["complete-urgent"] = "Atisen Dispatch: Urgent relay received with its signed manifest. 1,500 credits transferred. We'll finish the calibration here.",
  ["complete-recovery"] = "Atisen Dispatch: Relay and recovered manifest received. 2,000 credits transferred. We've recorded what happened to the convoy.",
  ["betrayed"] = "Crimbo Dispatch: Native records identify a breach of this convoy contract. All unpaid rewards are void. Return any held relay to close its custody record.",
  ["unavailable"] = "Dispatch: The assigned dispatch contact is unavailable. Keep the relay; your progress is saved. Another port cannot sign for this delivery.",
  ["return"] = "Crimbo Dispatch: Relay returned. Contract closed without a delivery payment.",
}
local function record(commands, cue)
  commands[#commands + 1] = {op = "journal.append", text = cues[cue]}
end
return {
  accepted = function(e, w, d)
    return {data = d, commands = {{op = "journal.append", text = cues.accepted}}}
  end,
  transition = function(e, w, d)
    local commands = {}
    local hasCrewPaid = false
    for _, receipt in ipairs(e.receipts or {}) do
      if receipt == "crewPaid" then hasCrewPaid = true end
    end
    for _, receipt in ipairs(e.receipts or {}) do
      if receipt == "manifest" and not w.provider.betrayed and w.provider.branch ~= "recovery" then record(commands, "calibrate")
      elseif receipt == "ready" and not w.provider.betrayed then
        if w.provider.branch == "full" then record(commands, "full-ready")
        elseif w.provider.branch == "recovery" then record(commands, "recovery-ready") end
      elseif receipt == "care" then
        if w.provider.crew_paid and not hasCrewPaid then record(commands, "rescue")
        elseif w.provider.crew_eligible_pending then
          commands[#commands + 1] = {op = "journal.append", text = "Crimbo Welfare: Safe handover recorded. Your eligible 500-credit crew commendation is pending payment."}
        end
      elseif receipt == "crewPaid" and w.provider.crew_paid then record(commands, "rescue")
      elseif receipt == "betrayed" then record(commands, "betrayed") end
    end
    for _, cue in ipairs(e.cues or {}) do
      if not w.provider.betrayed then
        if cue == "hello" and not w.provider.manifest then record(commands, "hello")
        elseif cue == "urgentChoice" and w.provider.urgent_review then record(commands, "urgent-choice")
        elseif cue == "disabled" and w.provider.branch == nil then record(commands, "disabled")
        elseif cue == "lostSanta" and w.provider.branch == nil then record(commands, "lost-santa")
        elseif cue == "sourceUnavailable" and w.provider.branch == nil then
          commands[#commands + 1] = {op = "journal.append", text = "Dispatch: The original convoy cannot authorize radio contact. Use an already authenticated manifest for urgent dispatch, recover original evidence, or return the held relay."}
        elseif cue == "unavailable" and w.provider.custody == "aboard" then record(commands, "unavailable") end
      end
    end
    for i = 1, 3 do
      if not w.provider.betrayed and math.floor((e.checkpoints or 0) / (2 ^ (i - 1))) % 2 == 1 then
        record(commands, "checkpoint" .. i)
      end
    end
    return {data = d, commands = commands}
  end,
  closed = function(e, w, d)
    local commands = {}
    if w.provider.stage == "completed" then
      local cue = w.provider.branch == "full" and "complete-full"
        or (w.provider.branch == "urgent" and "complete-urgent" or "complete-recovery")
      record(commands, cue)
    elseif w.provider.custody == "returned" then record(commands, "return")
    else commands[1] = {op = "journal.append", text = "Crimbo Dispatch: original relay genuinely lost; contract closed."} end
    return {data = d, commands = commands}
  end
}
