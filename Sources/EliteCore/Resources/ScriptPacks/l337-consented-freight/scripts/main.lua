return {
  generate = function(e,w,d)
    local offers={}
    for _,plan in ipairs(w.freight_plan) do
      offers[#offers+1]={key=plan.key,title="ARLEN / Eight original utility-parts tonnes / H0 / untimed",
        briefing="ARLEN: Reserve eight original Machinery utility-parts tonnes at Avenor, from one finite sixteen-tonne batch. Deliver those same units to the consenting utility receiving crew at Renas. Frozen reward "..(plan.reward/10).." CR / L"..plan.route_legs.." for the actual native route; H0, no deposit, no berths, no deadline. No restock after loss, abandonment, update or reinstall. Back changes nothing.",
        destination_galaxy=w.galaxy,destination_system=plan.destination,reward=plan.reward,
        deposit=0,failure_reward=0,refund_on_failure=false,duration=0,parameters=plan.parameters}
    end
    return {data={offers=offers},commands={}}
  end,
  accepted = function(e,w,d)
    return {data=d,commands={{op="journal.append",text="ARLEN: The eight original utility-parts tonnes are aboard. Source stock is allocated once. Deliver these same units to the consenting Renas utility receiving crew. No deadline."}}}
  end,
  contact = function(e,w,d)
    local commands={}
    if w.docked and w.main_station then
      if w.galaxy==w.contract.destination_galaxy and w.system==w.contract.destination_system then
        commands={{op="dialogue.offer",id="freight-delivery"}}
      elseif w.station_id==w.contract.station_id then
        commands={{op="dialogue.offer",id="freight-abandon"}}
      end
    end
    return {data=d,commands=commands}
  end
}
