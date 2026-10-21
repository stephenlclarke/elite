return {
  accepted = function(e,w,d)
    return {data=d,commands={{op="finance.offer",id="workshop"}}}
  end,
  contact = function(e,w,d)
    local loan=w.finance.workshop
    if loan and (loan.status=="outstanding" or loan.status=="paid") then
      return {data=d,commands={
        {op="milestone.ensure",index=0},
        {op="mission.finish",outcome="complete"}
      }}
    end
    return {data=d,commands={}}
  end
}
