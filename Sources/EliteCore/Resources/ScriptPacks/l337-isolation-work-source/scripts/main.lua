return {
  accepted = function(e, w, d)
    return {data = d, commands = {
      {op = "journal.append", text = "Lerr retains two original Renas feeder contacts and their finite utility accounts. Native admission and measured producer observations supply all isolation evidence."},
      {op = "timer.ensure", id = "native-deploy", domain = "local", after = 0.1, interval = 2.0, policy = "skip"}
    }}
  end,
  deploy = function(e, w, d)
    if w.galaxy == 0 and w.system == 185 and not w.docked then
      return {data = d, commands = {{op = "encounter.activate", id = "renas-feeders"}}}
    end
    return {data = d}
  end,
  admitted = function(e, w, d)
    return {data = d, commands = {{op = "timer.cancel", id = "native-deploy"}}}
  end
}
