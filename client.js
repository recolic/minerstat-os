var net = require('net');
var fs = require('fs');
var client = new net.Socket();
var exec = require('child_process').exec;

function handle(signal) {
  console.info('Sub process closed');
}

process.on('uncaughtException', function(err) {
  console.error("uncaughtException: " + err);
});
process.on('unhandledRejection', (reason, promise) => {
  console.error("unhandledRejection:" + reason.stack);
})

//process.on('SIGINT', handle);
process.on('SIGTERM', handle);

function connect() {
  client.connect(5000, '167.71.240.6', function() {
    console.log('[\x1B[32m OK \x1B[0m] Connected');
    fs.readFile('/media/storage/config.js', {
      encoding: 'utf-8'
    }, function(err, data) {
      if (!err) {
        var accessKey = data.split('global.accesskey')[1].split('"')[1];
        var workerName = data.split('global.worker')[1].split('"')[1];

        if (accessKey != '' && workerName != '') {
          client.write(accessKey + '.' + workerName + '\n');
        } else {
          console.log('[\x1B[31mFAIL\x1B[0m] Unable to parse config.js');
        }
      } else {
        console.log(err);
      }
    });
  });
}

// Connect first time
connect();

client.on('data', function(data) {
  var data = data.toString().replace(/\n$/, '');
  console.log("NEW COMMAND: %s", data);
  if (data == 'WELCOME') {
    console.log('[\x1B[32m OK \x1B[0m] Waiting for remote command ...');
  } else if (data == 'UNAUTHORIZED') {
    console.log('[\x1B[31mFAIL\x1B[0m] Unauthorized');
    client.destroy();
  } else if (data == 'INVALID WORKER') {
    console.log('[\x1B[31mFAIL\x1B[0m] Invalid worker');
    client.destroy();
  } else if (data == 'RESERVED') {
    console.log('[\x1B[31mFAIL\x1B[0m] Already authed');
    client.destroy();
  } else if (data != '') {
    exec('sudo bash /home/minerstat/minerstat-os/bin/commands ' + data, function(msg) {
      console.log(msg)
    });
  }
});

client.on('close', function() {
  console.log('Connection closed');
});