return {
  accepted = function(e, w, d)
    return {data = {}, commands = {
      {op = "journal.append", text = "PELL: Permission recorded for the same two depot-owned serials. Both remain at the Renas cradle until actual recovery. Their two tonnes are reserved; return the same originals to the actual Avenor depot. Pickup alone pays nothing."}
    }}
  end,
  deploy = function(e, w, d)
    local commands = {}
    local cohort = w.encounters["pell-wreck"]
    if w.galaxy == 0 and w.system == 185 and not w.docked
      and (not cohort or not cohort.admitted) then
      commands = {{op = "encounter.ensure", id = "pell-wreck"}}
    end
    return {data = d, commands = commands}
  end
}
