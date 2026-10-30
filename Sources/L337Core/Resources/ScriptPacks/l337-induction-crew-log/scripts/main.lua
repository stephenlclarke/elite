return {
  accepted = function(e, w, d)
    return {data = d, commands = {
      {op = "journal.append", text = "The original Cevilis tender, marked two-person launch and custody recorder remain custodian property. Only actual native admission and original recorder pickup can establish progress."},
      {op = "timer.ensure", id = "native-deploy", domain = "local", after = 0.1, interval = 2.0, policy = "skip"}
    }}
  end,
  deploy = function(e, w, d)
    if w.galaxy == 0 and w.system == 211 and not w.docked then
      return {data = d, commands = {{op = "encounter.activate", id = "cevilis-source"}}}
    end
    return {data = d}
  end,
  admitted = function(e, w, d)
    return {data = d, commands = {{op = "timer.cancel", id = "native-deploy"}}}
  end
}
