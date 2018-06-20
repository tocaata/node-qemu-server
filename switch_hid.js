#!/usr/bin/env node

var io = require('socket.io-client');

class QMP {
  constructor(url) {
    this.url = url;
    this.socket = io.connect(url);
    this.socket.on('connect', () => {
      console.log('SOCK -> connected');
    });

    this.socket.on('msg', (msg) => {
      console.log(`message: ${msg}`);
    });

    this.socket.on('update-config', () => {});
    this.socket.on('set-vm', () => {});
    this.socket.on('set-host', () => {});
    this.socket.on('set-disk', () => {});

    this.socket.on('qmp', (ret) => {
      let cmd = this.commands.pop();
      cmd(ret);
    });
  }

  exec(command, callback) {
    if (typeof(callback) === 'function') {
      1
    } else {
      return new Promise((resolve, reject) => {
        this.commands.push((content) => {
          resolve(content);
        });
        this.socket.emit(JSON.stringify(command));
      });
    }
  }

  close() {
  }
}


async function run() {
  let qmp = new QMP('http://192.168.0.3:4224/');
  setTimeout(() => {console.log("exec\n");qmp.exec({add_object: 'ass'});}, 2000)
  // let result = await qmp.exec({add_object: 'ass'});
  // console.log(result);
  // result = await qmp.exec({add_object: 'bbb'});
  // result = await qmp.exec({remove_object: 'ccc'});
}

run();