#!/usr/bin/env node

var io = require('socket.io-client');

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
      1
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
  let qmp = new QMP('http://192.168.0.3:4224/');
  setTimeout(() => {console.log("exec\n");qmp.exec('win10', 'system_powerdown', {}); qmp.close();}, 2000);
  
  // let result = await qmp.exec({add_object: 'ass'});
  // console.log(result);
  // result = await qmp.exec({add_object: 'bbb'});
  // result = await qmp.exec({remove_object: 'ccc'});
}

run();
