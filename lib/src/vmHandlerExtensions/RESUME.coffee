
socketServer = require '../../socketServer'

module.exports = (vm) ->
  console.log "vmHandler Extension received RESUME event"

  vm.setStatus 'running'
  socketServer.toAll 'set-vm-status', vm.name, 'running'
  socketServer.toAll 'msg', {type:'success', msg:"VM #{vm.name} resume."}
  if vm.cfg.hid
    vm.attachHid ->
      socketServer.toAll 'update-vm', curVm.cfg
