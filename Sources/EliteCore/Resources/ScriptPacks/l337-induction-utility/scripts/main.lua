return {
  accepted = function(e, w, d)
    return {data = d, commands = {
      {op = "journal.append", text = "Enron utility crew retain all three original modules and sealed local kits. Maintenance authorization and native admission alone repair nothing."},
      {op = "timer.ensure", id = "native-deploy", domain = "local", after = 0.1, interval = 2.0, policy = "skip"}
    }}
  end,
  deploy = function(e, w, d)
    if w.galaxy == 0 and w.system == 190 and not w.docked then
      return {data = d, commands = {{op = "encounter.activate", id = "enron-handoffs"}}}
    end
    return {data = d}
  end,
  admitted = function(e, w, d)
    return {data = d, commands = {{op = "timer.cancel", id = "native-deploy"}}}
  end
}
