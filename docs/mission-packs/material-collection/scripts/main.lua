local function at_station(w)
  return w.galaxy == 0 and w.system == 7 and w.docked and w.main_station
end
return {
  accepted = function(e,w,d)
    return {data=d,commands={{op="collection.ensure",id="materials"}}}
  end,
  contact = function(e,w,d)
    if at_station(w) then
      return {data=d,commands={{op="dialogue.offer",id="handoff"}}}
    end
    return {data=d,commands={}}
  end,
  confirm = function(e,w,d)
    local quote=w.collections.materials.quote
    local complete=true
    for _,item in ipairs(quote) do
      if item.quantity < item.outstanding then complete=false end
    end
    local commands={{op="collection.deliver",id="materials",token=e.token}}
    if complete then
      commands[2]={op="milestone.ensure",index=0}
      commands[3]={op="mission.finish",outcome="complete"}
    end
    return {data=d,commands=commands}
  end
}
