
net       = require 'net'
vmHandler = require '../vmHandler'

class Qmp
  constructor:(@vmName) ->
    @socket = undefined
    @port   = undefined
    @dataCb = undefined

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
            console.dir  parsedData
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
              if parsedData.error?
                @dataCb 'error':parsedData.error
              else if parsedData.timestamp?
                continue
              else if parsedData.return?
                if 0 is Object.keys(parsedData.return).length
                  @dataCb status:'success'
                else
                  @dataCb 'data':parsedData.return
              else
                console.error "cant process Data"
                console.error parsedData
              @dataCb = undefined
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
        else
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

  hid_attach: (cb) ->
    @sendCmd "device_add", {'driver':'usb-host', 'vendorid':'1133', 'productid':'49734'}, () ->
      @sendCmd "device_add", {'driver':'usb-host', 'vendorid':'6940', 'productid':'6919'}, cb

  hid_unattach: (cb) ->
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
      cur = null
      for hid in hids
        if cur == null
          cur = new Promise((resolve, reject) ->
            that.sendCmd "device_del", hid, () ->
              resolve()
          )
        else
          cur = cur.then(() ->
            return tmp = new Promise((resolve, reject) ->
              that.sendCmd "device_del", hid, () ->
                resolve()
            )
          )
    )
  

  # hid_unattach: (cb) ->
  #   paths = [{'path':'/machine/unattached'}, {'path':'/machine/peripheral-anon'}]
  #   reduce_func = (result, arg) ->
  #     hids = []
  #     for r in result.data
  #       if r.type == "child<usb-host>"
  #         hids.push({'id':arg.path + r.name})

  #   result_func = (data) ->
  #     1
  #   recur "qom-list", paths, reduce_func, result_func

  #   @sendCmd "qom-list", {'path':'/machine/unattached'}, (result) ->
  #     hids = []
  #     for r in result.data
  #       if r.type == "child<usb-host>"
  #         hids.push({'id':"/machine/unattached/" + r.name})
  #     @sendCmd "qom-list", {'path':'/machine/peripheral-anon'}, (result) ->
  #       for r in result.data
  #         if r.type == "child<usb-host>"
  #           hids.push({'id':"/machine/peripheral-anon/" + r.name})
  #       recur("device_del", hids)
  #   cb()

  # recur: (exec, argument_array, reduce_func, result_func) ->
  #   if argument_array.length <= 0
  #     return false
  #   if typeof reduce_func is not 'function'
  #     reduce_func = ->
  #   if typeof result_func is not 'function'
  #     result_func = ->
  #   if argument_array.length == 1
  #     arg = argument_array.pop()
  #     @sendCmd exec, arg, (result) ->
  #       results = reduce_func(result, arg)
  #       result_func results
  #   else
  #     arg = argument_array.pop()
  #     @sendCmd exec, arg, (result) ->
  #       results = reduce_func(result, arg)
  #       recur exec, argument_array, reduce_func.bind(results), result_func

exports.Qmp = Qmp
