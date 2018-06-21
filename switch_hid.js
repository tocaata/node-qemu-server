#!/usr/bin/env node

var io = require('socket.io-client');
var fs = require('fs');

const serverUrl = 'http://192.168.0.3:4224/';
const vms = ['win10', 'MacOS Sierra'];
const curVmFile ='/var/run/active_vm';
const keyboardPath = "/dev/input/by-id/usb-Corsair_Corsair_K65_Gaming_Keyboard-if02-event-kbd";
const mousePath = "/dev/input/by-id/usb-Logitech_Gaming_Mouse_G300-event-mouse";


class QMP {
  constructor(url) {
    this.url = url;
    this.commands = [];
    this.socket = io.connect(url);
    this.socket.on('connect', () => {
      console.log('SOCK -> connected');
    });

    this.socket.on('msg', (msg) => {
      console.log(`message: ${msg}`);
    });

    this.socket.on('update-config', () => {console.log('update-config')});
    this.socket.on('set-vm', () => {console.log('set-vm');});
    this.socket.on('set-host', () => {console.log('set-host')});
    this.socket.on('set-disk', () => {console.log('set-disk')});

    this.socket.on('qmp', (ret) => {
      let cmd = this.commands.pop();
      cmd(ret);
    });
  }

  exec(vmName, command, args, callback) {
    if (typeof(callback) === 'function') {
      this.commands.push(callback);
      this.socket.emit('qmp', command, args, vmName);
      return ;
    } else {
      return new Promise((resolve, reject) => {
        this.commands.push((content) => {
          resolve(content);
        });
        this.socket.emit('qmp', command, args, vmName);
      });
    }
  }

  close() {
    this.socket.disconnect();
  }
}


async function run() {
  let activeVm = fs.readFileSync(curVmFile, 'utf-8');
  console.log(`current vm is '${activeVm}'`);
  if (activeVm.length === 0 || vms.indexOf(activeVm) < 0) {
    activeVm = vms[0];
  }
  console.log(`current vm is '${activeVm}'`);
  let qmp = new QMP(serverUrl);
  let ret = await qmp.exec(activeVm, 'object-del', {"id": "kbd3"});
  console.log(ret);
  ret = await qmp.exec(activeVm, 'object-del', {"id": "mouse1"});
  console.log(ret);

  let pos = vms.indexOf(activeVm);
  pos = (pos + 1) % vms.length;
  const vmName = vms[pos];

  fs.writeFileSync(curVmFile, vmName);
  ret = await qmp.exec(vmName, 'object-add', {"qom-type": "input-linux", "id":"kbd3", "props": {"evdev":keyboardPath, "grab_all": true}});
  console.log(ret);
  ret = await qmp.exec(vmName, 'object-add', {"qom-type": "input-linux", "id":"mouse1", "props": {"evdev":mousePath}});
  console.log(ret);

  qmp.close();
  //setTimeout(() => {console.log("exec\n");qmp.exec('win10', 'system_powerdown', {}); qmp.close();}, 2000);
  
  // let result = await qmp.exec({add_object: 'ass'});
  // console.log(result);
  // result = await qmp.exec({add_object: 'bbb'});
  // result = await qmp.exec({remove_object: 'ccc'});
}


run();
