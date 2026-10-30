return {
  accepted = function(e, w, d)
    return {data = {}, commands = {
      {op = "journal.append", text = "SOREL: Lysa and Tovan are actually aboard for three ordered Renas views and return. Native observation needs 12 continuous seconds per next marker. Return both to real Avenor care; scans alone cannot pay."}
    }}
  end,
  deploy = function(e, w, d)
    local commands = {}
    local cohort = w.encounters["orbital-views"]
    if w.galaxy == 0 and w.system == 185 and not w.docked
      and (not cohort or not cohort.admitted) then
      commands = {{op = "encounter.ensure", id = "orbital-views"}}
    end
    return {data = d, commands = commands}
  end
}
