
vmHandler = require './vmHandler'
ioServer  = undefined
Disk      = require './src/disk'
parser    = require './src/parser'
settings  = require('./src/settings').settings

socks  = {}

module.exports.start = (httpServer) ->
  ioServer = require('socket.io').listen httpServer
  ioServer.set('log level', 1)
  
  ioServer.sockets.on 'connection', (sock) ->
    socks[sock.id] = sock
    console.log "SOCK -> CON #{sock.handshake.address.address}"
    console.log "SOCK -> count: #{Object.keys(socks).length}"
  
    sock.emit('set-iso', iso) for iso in vmHandler.getIsos()                    # emit iso  names, client drops duplicates
    
    for disk in vmHandler.getDisks()                                            # emit disks, client drops duplicates
      Disk.info disk, (ret) ->
        sock.emit 'set-disk', ret.data

    sock.emit('update-config', settings)
    
    sock.emit('set-vm', vm.cfg) for vm in vmHandler.getVms()                    # emit vms, client drops duplicates
    
    #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #   #
  
    sock.on 'disconnect', ->
      console.log "SOCK -> DIS #{sock.id} #{sock.handshake.address.address}"
      delete socks[sock.id]
      
    sock.on 'qmp-command', (qmpCmd, vmName) ->
      console.log "QMP-Command #{qmpCmd}"
      vmHandler.qmpCommand qmpCmd, vmName

    sock.on 'attachHid', (vmName) ->
      vmHandler.attachHid vmName, () ->
        console.log "AddHid #{vmName}"

    sock.on 'unattachHid', (vmName) ->
      vmHandler.unattachHid vmName, () ->
        console.log "Remove Hid #{vmName}"

    sock.on 'create-disk', (disk) ->
      vmHandler.createDisk disk, (ret) ->
        sock.emit 'msg', ret
        if ret.status is 'success'
          sock.emit 'reset-create-disk-form'
          ioServer.sockets.emit 'set-disk', ret.data.data


    sock.on 'delete-disk', (diskName) ->
      if vmHandler.deleteDisk diskName
        sock.emit 'msg', {type:'success', msg:'image deleted'}
        ioServer.sockets.emit 'delete-disk', diskName
      else
        sock.emit 'msg', {type:'error',   msg:'cant delete image'}
          
    sock.on 'delete-iso', (isoName) ->
      if vmHandler.deleteIso isoName
        sock.emit 'msg', {type:'success', msg:"Deleted iso #{isoName}."}
        ioServer.sockets.emit 'delete-iso', isoName
      else
        sock.emit 'msg', {type:'error', msg:"Can't delete iso #{isoName}."}
          
    sock.on 'create-VM', (vmCfg) ->
      vmHandler.createVm vmCfg, (ret) ->
        sock.emit 'msg', ret
        
        if ret.status is 'success'
          sock.emit 'reset-create-vm-form'

    sock.on 'remove-VM', (vmName) ->
      vmHandler.removeVM vmName, (ret) ->
        sock.emit 'msg', ret

    sock.on 'edit-VM', (vmCfg) ->
      vmHandler.editVm vmCfg, (ret) ->
        sock.emit 'msg', ret
        
        if ret.status is 'success'
          sock.emit 'reset-create-vm-form'

          
    sock.on 'see-VM', (vmCfg) ->
      args = parser.vmCfgToArgs vmCfg
      console.log args
      sock.emit 'msg', {type:'success', msg:"show qemu argument."}
      sock.emit 'show-VM', "qemu-system-x86_64" + args.args.join(" ")

module.exports.toAll = (msg, args...) ->
  ioServer.sockets.emit msg, args...
