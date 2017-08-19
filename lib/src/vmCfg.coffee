
fs = require 'fs'

save = (vmCfg) ->
  try fs.writeFileSync "vmConfigs/#{vmCfg.name}.json", JSON.stringify vmCfg
  catch e
    console.error "save error"
    console.dir    e
    return false
  return true

open = (vmName, cb) ->
  try
    cfg = fs.readFileSync "vmConfigs/#{vmName}.json"
    cb {status:'success', data:JSON.parse(cfg)}
  catch e
    console.dir e
    cb {status:'error', data:undefined}

remove = (vmName) ->
  try
    fs.unlinkSync "vmConfigs/#{vmName}.json"
  catch e
    console.error "remove #{vmName} error"
    return false
  return true
  

exports.save   = save
exports.open   = open
exports.remove = remove