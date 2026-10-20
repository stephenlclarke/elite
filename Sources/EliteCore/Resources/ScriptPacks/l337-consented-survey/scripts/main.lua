return {
  accepted = function(e, w, d)
    return {data = {}, commands = {
      {op = "journal.append", text = "Avenor survey permission recorded. Measure the three registered Renas calibration targets in order using the fitted targeting computer. Return the completed measurements to actual Avenor reception; scans alone cannot pay."}
    }}
  end,
  deploy = function(e, w, d)
    local commands = {}
    local cohort = w.encounters["survey-points"]
    if w.galaxy == 0 and w.system == 185 and not w.docked
      and (not cohort or not cohort.admitted) then
      commands = {{op = "encounter.ensure", id = "survey-points"}}
    end
    return {data = d, commands = commands}
  end
}
