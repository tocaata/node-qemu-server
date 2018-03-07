module.exports.update = (sobject,hash) ->
  for key,value of hash
    if sobject.hasOwnProperty key
      sobject[key] = value
