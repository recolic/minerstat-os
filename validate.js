/*
	GLOBAL FUNCTION's
*/
"use strict";
global.path = __dirname;

var colors = require('colors'),
  exec = require('child_process').exec,
  fs = require('fs'),
  path = require('path'),
  pump = require('pump'),
  sleep = require('sleep'),
  tools = require('./tools.js'),
  monitor = require('./monitor.js'),
  settings = require("./config.js");


console.log(global.accesskey);
console.log(global.worker);