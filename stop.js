/*
	USER => mstop
*/
"use strict";
global.path = __dirname;
var settings = require("./config.js");
/*
	CATCH ERROR's
*/
process.on('SIGINT', function() {});
process.on('uncaughtException', function(err) {})
process.on('unhandledRejection', (reason, p) => {});
const fkill = require('fkill');
var exec = require('child_process').exec;
try {
  fkill('cpuminer').then(() => {});
  fkill('bminer').then(() => {});
  fkill('zm').then(() => {});
  fkill('zecminer64').then(() => {});
  fkill('ethminer').then(() => {});
  fkill('ethdcrminer64').then(() => {});
  fkill('miner').then(() => {});
  fkill('sgminer').then(() => {});
  fkill('nsgpucnminer').then(() => {});
  fkill('xmr-stak').then(() => {});
  fkill('t-rex').then(() => {});
  fkill('CryptoDredge').then(() => {});
  fkill('lolMiner').then(() => {});
  fkill('mkxminer').then(() => {});
  fkill('xmrig').then(() => {});
  fkill('xmrig').then(() => {}); // yes twice
  fkill('xmrig-amd').then(() => {});
  fkill('z-enemy').then(() => {});
  fkill('PhoenixMiner').then(() => {});
  fkill('wildrig-multi').then(() => {});
  fkill('progpowminer').then(() => {});
  fkill('teamredminer').then(() => {});
  fkill('cast_xmr-vega').then(() => {});
  fkill('zjazz_cuda').then(() => {});
  fkill('GrinProMiner').then(() => {});
  fkill('serominer').then(() => {});
  fkill('nbminer').then(() => {});
  fkill('nanominer').then(() => {});
  fkill('kbminer').then(() => {});
  fkill('vkminer').then(() => {});
  fkill('SRBMiner-MULTI').then(() => {});
} catch (e) {}
var request = require('request');
//console.log(res_data);
//console.log(global.accesskey);
//console.log(global.worker);
request.post({
  url: 'https://api.minerstat.com/v2/set_node_config.php?token=' + global.accesskey + '&worker=' + global.worker + '&miner=&ver=4&cpuve=idle&cpud=HASH' + '&os=linux&hwNew=true&',
  form: {
    minerData: "",
    cpuData: ""
  }
}, function(error, response, body) {
  var killScreen = exec("SID=$(screen -list | grep minerstat-console | cut -f1 -d'.' | sed 's/[^0-9]*//g'); screen -X -S $SID'.minerstat-console'", function(error, stdout, stderr) {}),
    killNode = exec("killall node", function(error, stdout, stderr) {});
});
