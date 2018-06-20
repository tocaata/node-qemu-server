#!/usr/bin/env node

var WebSocketClient = require('websocket').client;



class QMP {
  constructor(url) {
    super(url);
    this.url = url;
    this.client = new WebSocketClient();
    this.commands = [];
  }

  static connect(url) {
    let qmp = new QMP(url);
    qmp._connect(url);
  }

  exec(command, callback) {
    return new Promise((resolve, reject) => {
      this.sendUTF(command.toString());
      this.commands.push((content) => {
        resolve(content);
      })
    });
  }

  _connect(url) {
    this.client.on('connectFailed', (error) => {
      console.log('Connect Error: ' + error.toString());
    });

    this.client.on('connect', (connection) => {
      console.log('WebSocket Client Connected');
      connection.on('error', (error) => {
        console.log('Connect Error: ' + error.toString());
      });

      connection.on('close', () => {
        console.log('echo-protocol connection closed');
      });

      connection.on('message', (message) => {
        if (message.type == 'utf8') {
          console.log(`Received: '${message.utf8Data}'`);
          let cmd = this.commands.pop();
          cmd(message);
        }
      });
    });
    this.client.connect(`ws://${url}/`, 'echo-protocol');
  }
}

client.on('connectFailed', (error) => {
  console.log('Connect Error: ' + error.toString());
});

client.on('connect', (connection) => {
  console.log('WebSocket Client Connected');
  connection.on('error', (error) => {
    1
  });
});

async function run() {
  let qmp = QMP.connect('localhost:4334');
  let result = await qmp.exec({add_object: 'ass'});
  result = await qmp.exec({add_object: 'bbb'});
  result = await qmp.exec({remove_object: 'ccc'});
}

run();