Vm     = require('./src/vm').Vm

class VmSet extends Array
  attachHid: (vmName, cb) ->
  	curVm = null
  	for v in @
  	  if v.name == vmName
  	  	curVm = v
    for vm in @
      if vm.hid
        vm.unattachHid (ret) ->
      	  curVm.attachHid ->
      	  	cb(vm.cfg, curVm.cfg)
      	return
    curVm.attachHid ->
    	cb(undefined, curVm.cfg)

exports.VmSet = VmSet
