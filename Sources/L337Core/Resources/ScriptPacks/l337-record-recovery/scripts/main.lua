return {
  accepted = function(e, w, d)
    return {data = {}, commands = {
      {op = "journal.append", text = "SENN: Permission recorded for archive-owned CDR-001. One tonne is reserved while the original remains at the Celalen cradle. First identify it with actual fitted targeting and clear sight; separately later recover it and return it to the actual Cedamar archive. Identification or pickup alone pays nothing."}
    }}
  end,
  deploy = function(e, w, d)
    local commands = {}
    local cohort = w.encounters["w05-wreck"]
    if w.galaxy == 0 and w.system == 241 and not w.docked
      and (not cohort or not cohort.admitted) then
      commands = {{op = "encounter.ensure", id = "w05-wreck"}}
    end
    return {data = d, commands = commands}
  end
}
