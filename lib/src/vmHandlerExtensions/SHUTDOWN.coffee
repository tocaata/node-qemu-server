
socketServer = require '../../socketServer'
vmHandler    = require '../../vmHandler'

module.exports = (vm) ->
  console.log "vmHandler Extension received SHUTDOWN event"
  console.log "qemu process exit VM #{vm.name}"

  vm.setStatus 'stopped'
  vmHandler.tryShutdownHost ->
  socketServer.toAll 'set-vm-status', vm.name, 'stopped'
  socketServer.toAll 'msg', {type:'success', msg:"VM #{vm.name} shutdown."}
