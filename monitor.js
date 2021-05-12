var monitorObject = {};
module.exports = {
  /*
  	DETECT VIDEO CARD TYPE
  */
  detect: function() {
    var exec = require('child_process').exec,
      child;
    global.gputype = "unknown";
    child = exec("nvidia-smi -L", function(error, stdout, stderr) {
      var response = stdout;
      if (response.indexOf("GPU 0:") > -1) {
        global.gputype = "nvidia";
      }
      if (error !== null) {
        console.log('Hardware Monitor: Nvidia GPU not found');
      }
    });
    child = exec(global.path + "/bin/amdcovc", function(error, stdout, stderr) {
      var response = stdout;
      if (response.indexOf("Adapter") !== -1) {
        global.gputype = "amd";
      }
      if (error !== null) {
        console.log('Hardware Monitor: AMD GPU not found');
      }
    });
  },
  /*
  	AMDCOVC - AMD
  */
  HWamd: function(gpuSyncDone, cpuSyncDone) {

    var strapFileName = "amdmemorytweak-stable";
    if (global.osversion == "experimental") {
      strapFileName = "amdmemorytweak";
    }

    var exec = require('child_process').exec,
      query = exec("cd " + global.path + "/bin/; sudo ./amdinfo", function(error, stdout, stderr) {
        var amdResponse = stdout,
          queryPower = exec("cd " + global.path + "/bin/; sudo ./rocm-smi -P | grep 'Average Graphics Package Power:' | sed 's/.*://' | sed 's/W/''/g' | xargs", function(error, stdout, stderr) {
            var hwmemory = exec("cd " + global.path + "/bin/; cat amdmeminfo.txt", function(memerror, memstdout, memstderr) {
              var hwstraps = exec("cd " + global.path + "/bin/; sudo ./" + strapFileName + " --current-minerstat", function(straperror, strapstdout, strapstderr) {
                isfinished(amdResponse, "amd", gpuSyncDone, cpuSyncDone, stdout, memstdout, strapstdout);
              });
            });
          });
      });
  },
  /*
  	NVIDIA-SMI - NVIDIA
  */
  HWnvidia: function(gpuSyncDone, cpuSyncDone) {
    var exec = require('child_process').exec,
      fetchNvidia = exec("cd " + global.path + "/bin/; sudo ./gpuinfo nvidia", function(error, stdout, stderr) {
        isfinished(stdout, "nvidia", gpuSyncDone, cpuSyncDone, "", "", "");
      });

  }
}

function isfinished(hwdatar, typ, gpuSyncDone, cpuSyncDone, powerResponse, hwmemory, hwstrap) {
  if (typ === "nvidia") {
    var hwdatas = hwdatar;
  } else {
    var hwdatas = hwdatar,
      hwPower = powerResponse;
  }
  /*
  	MAIN FUNCTIONS
  */
  //console.log("[" + typ + "] Hardware Monitor: " + hwdatas);
  /*
  	SEND DATA TO ENDPOINT
  */
  // UNSET
  monitorObject = {};
  var main = require('./start.js');
  main.callBackHardware(hwdatas, gpuSyncDone, cpuSyncDone, hwPower, hwmemory, hwstrap);
}