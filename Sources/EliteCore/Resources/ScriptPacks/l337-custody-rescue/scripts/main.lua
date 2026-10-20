return {
  accepted = function(e, w, d)
    return {data = {}, commands = {
      {op = "journal.append", text = "DAIN: Recover each original living capsule separately into actual Cedamar care. Then ask for voluntary Celalen replies, board the same people, and recover their original physical record. Only complete actual Celalen reception pays 1020 CR."}
    }}
  end,
  deploy = function(e, w, d)
    local cohort = w.encounters["cedamar-rescue"]
    local commands = {}
    if w.galaxy == 0 and w.system == 85 and not w.docked
      and (not cohort or not cohort.admitted) then
      commands = {{op = "encounter.ensure", id = "cedamar-rescue"}}
    end
    return {data = d, commands = commands}
  end
}
