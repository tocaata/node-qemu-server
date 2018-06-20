proc   = require './process'
qmp    = require './qmp'
vmConf = require('./vmCfg')
jsonHelper = require './jsonHelper'

class Vm
  constructor: (@cfg) ->
    @name    = @cfg.name
    @process = new proc.Process()
    @qmp     = new qmp.Qmp @name, @cfg.settings.usbBus
    vmConf.save @cfg
  edit: (cfg) ->
    for key,value of cfg
      if @cfg.hasOwnProperty key
        if @cfg[key].constructor == Object && value.constructor == Object
          jsonHelper.update(@cfg[key], value)
        else
          @cfg[key] = value

    delete @qmp
    delete @process
    @process = new proc.Process()
    @qmp     = new qmp.Qmp @name, @cfg.settings.usbBus

    vmConf.save @cfg
    @

  remove: () ->
    delete @qmp
    delete @process
    vmConf.remove @name
  
  setStatus: (status) ->
    @cfg.status = status
    vmConf.save @cfg

  start: (cb) ->
    that = @
    @process.start @cfg
    @qmp.connect   @cfg.settings.qmpPort, (ret) =>
      if that.cfg.settings.vnc
        that.qmp.setVncPass(that.cfg.settings.vncPassword, -> )
      cb ret
      @status()
  
  connectQmp: (cb) ->
    @qmp.connect   @cfg.settings.qmpPort, (ret) =>
      cb ret
      @status()

  qmpCmd: (cmd, args, cb) ->
    @qmp.sendCmd cmd, args, cb
    
  stopQMP: ->
    console.log "VM #{@name}: stopQMP called"
    @qmp.stopReconnect()
    delete @qmp
    @qmp   = new qmp.Qmp @name
  
  ###
  #   QMP commands
  ###  
  pause: (cb) ->
    @qmp.pause cb

  reset: (cb) ->
    @qmp.reset cb
    
  resume: (cb) ->
    @qmp.resume cb

  shutdown: (cb) ->
    @qmp.shutdown cb

  stop: (cb) ->
    @qmp.stop cb
    
  status: ->
    @qmp.status()

  attachHid: (cb) ->
    that = @
    if @cfg.status == 'stopped'
      @cfg.hid = true
      vmConf.save @cfg
      cb()
      return
    @qmp.attachHid ->
      that.cfg.hid = true
      vmConf.save that.cfg
      cb()

  unattachHid: (cb) ->
    that = @
    if @cfg.status == 'stopped'
      @cfg.hid = false
      vmConf.save @cfg
      return cb()
    @qmp.unattachHid (ret) ->
      that.cfg.hid = false
      vmConf.save that.cfg
      cb(ret)

exports.Vm = Vm
  


# qVM.gfx()
#    .ram(1024)
#    .cpus(2)
#    .accel('kvm')
#    .vnc(2)
#    .mac('52:54:00:12:34:52')
#    .net()
#    .qmp(4442)
#    .hd('ub1210.img')
#    .keyboard('de')


# console.dir qVM.startArgs
# 
# # qVM.start ->
# #   console.log "qemu VM startet"
# 
# qVM.reconnectQmp 4442, ->
#   console.log "reconnected to qmp"  
  
  # qemu  -cpu kvm64


###    
  
#       @qmpSocket.write '{"execute":"query-commands"}'  

###
