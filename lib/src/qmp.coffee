
net       = require 'net'
util      = require 'util'
vmHandler = require '../vmHandler'

class Qmp
  constructor:(@vmName) ->
    @socket = undefined
    @port   = undefined
    @dataCb = undefined
    @close  = false

  stopReconnect: ->
    console.log "Stop reconnect catched"
    @close = true

  connect: (port, cb) ->
    if      typeof port is 'function'
      cb = port
    else if typeof port is 'number'
      @port = port

    console.log "QMP: try to connect to VM #{@vmName} with port #{@port}"
      
    setTimeout =>                                                               # give the qemu process time to start
      @socket = net.connect @port
      
      @socket.on 'connect', =>
        console.log "qmp connected to #{@vmName}"
        @socket.write '{"execute":"qmp_capabilities"}'
        cb status:'success'
        
      @socket.on 'data', (data) =>
        jsons = data.toString().split '\r\n'
        jsons.pop()                                                             # remove last ''
  
        for json in jsons
          try
            parsedData = JSON.parse json.toString()
            if parsedData.event? then event = parsedData.event else event = undefined

            console.log " - - - QMP-START-DATA - - -"
            #console.dir  parsedData
            console.log   util.inspect(parsedData).slice(0, 256)
            console.log " - - - QMP-END-DATA - - -"

            if parsedData.return?.status?     and
               parsedData.return?.singlestep? and
               parsedData.return?.running?
              parsedData.timestamp = new Date().getTime()
              if      parsedData.return.status is 'paused'
                event = 'STOP'
              else if parsedData.return.status is 'running' and parsedData.return.running is true
                parsedData.timestamp = new Date().getTime()
                event = 'RESUME'

            # handle events
            if parsedData.timestamp? and event?
              if vmHandler[event]?
                console.log "QMP: call vmHandler[#{event}] for VM #{@vmName}"
                vmHandler[event] @vmName
            if @dataCb?
              callback = @dataCb
              if parsedData.error?
                @dataCb = undefined
                callback 'error':parsedData.error
              else if parsedData.timestamp?
                continue
              else if parsedData.return?
                @dataCb = undefined
                if 0 is Object.keys(parsedData.return).length
                  callback status:'success'
                else
                  callback 'data':parsedData.return
              else
                console.error "cant process Data"
                console.error parsedData
            else
#               console.log "no callback defined:"
#               console.dir parsedData
          catch e
            console.error "cant parse returned json, Buffer is:"
            console.error  json.toString()
            console.error "error is:"
            console.dir    e
  
      @socket.on 'error', (e) =>
        if e.message is 'This socket has been ended by the other party'
          console.log 'QEMU closed connection'
        else if @close != true
          console.error 'QMP: ConnectError try reconnect'
          @connect cb
    , 1000
      
  sendCmd: (cmd, args, cb) ->
    if typeof args is 'function'
      @dataCb = args
      @socket.write JSON.stringify execute:cmd
    else
      @dataCb = cb
      @socket.write JSON.stringify {execute:cmd, arguments: args }

  reconnect: (port, cb) ->
    @connect port, cb
    
  ###
  #   QMP commands
  ###
  pause: (cb) ->
    @sendCmd 'stop', cb
    
  reset: (cb) ->
    @sendCmd 'system_reset', cb
    
  resume: (cb) ->
    @sendCmd 'cont', cb
    
  shutdown: (cb) ->
    @sendCmd 'system_powerdown', cb
    
  stop: (cb) ->
    @sendCmd 'quit', cb
    
  status: ->
    @sendCmd 'query-status', ->
  
  balloon: (mem, cb) ->
    @sendCmd 'balloon', {value:mem}, cb

  attachHid: (cb) ->
    that = @
    that.sendCmd "device_add", {'driver':'usb-host', 'vendorid':'1133', 'productid':'49734'}, (result) ->
      that.sendCmd "device_add", {'driver':'usb-host', 'vendorid':'6940', 'productid':'6919'}, (result1) ->
        cb()

  unattachHid: (cb) ->
    that = @
    tmp = new Promise((resolve, reject) ->
      that.sendCmd "qom-list", {'path':'/machine/unattached'}, (result) ->
        hids = []
        for r in result.data
          if r.type == "child<usb-host>"
            hids.push({'id':"/machine/unattached/" + r.name})
        resolve(hids)
    ).then((hids) ->
      tmp = new Promise((resolve, reject) ->
        that.sendCmd "qom-list", {'path':'/machine/peripheral-anon'}, (result) ->
          hids = hids || []
          for r in result.data
            if r.type == "child<usb-host>"
              hids.push({'id':"/machine/peripheral-anon/" + r.name})
          resolve(hids)
      )
    ).then((hids)->
      fun = cb
      getFun = (hid, callback) ->
        () ->
          that.sendCmd "device_del", hid, callback
      for hid in hids
        fun = getFun(hid, fun)
      fun()
    )

exports.Qmp = Qmp
