return {
  expire = function(e, w, d)
    return {data = d, commands = {{op = "cold-chain.expire"}}}
  end
}
