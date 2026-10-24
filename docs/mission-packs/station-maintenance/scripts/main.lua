return {
  accepted = function(e,w,d)
    assert(w.galaxy==0 and w.system==7 and w.main_station,
      'Visit Lave main orbital station to authorize this service.')
    return {data={},commands={
      {op='world.job.ensure',id='patrol-service'},
      {op='milestone.ensure',index=0},
      {op='milestone.ensure',index=1},
      {op='mission.finish',outcome='complete'}}}
  end,
  maintenance = function(e,w,d)
    if w.encounters.support and w.encounters.support.admitted then
      return {data=d,commands={
        {op='job.journal.append',text='Both actual support ships were admitted. No mission reward was issued.'},
        {op='job.finish'}}}
    end
    if e.counters.opening>=3 then
      return {data=d,commands={{op='encounter.ensure',id='support'}}}
    end
    return {data=d,commands={}}
  end
}
