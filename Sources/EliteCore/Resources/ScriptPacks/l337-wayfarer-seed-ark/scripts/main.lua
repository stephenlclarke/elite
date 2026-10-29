return {
  accepted = function(e, w, d)
    return {data = d, commands = {
      {op = "journal.append", text = "The custodian's registered original seed ark is reserved. Only native departure, route service and receiving records can establish progress."},
      {op = "timer.ensure", id = "native-launch", domain = "local", after = 0.1, interval = 2.0, policy = "skip"}
    }}
  end,
  launch = function(e, w, d)
    if w.galaxy == 0 and w.system == 162 and not w.docked then
      return {data = d, commands = {{op = "encounter.activate", id = "registered-ark"}}}
    end
    return {data = d}
  end,
  admitted = function(e, w, d)
    return {data = d, commands = {{op = "timer.cancel", id = "native-launch"}}}
  end
}
