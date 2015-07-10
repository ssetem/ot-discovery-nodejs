var path              = require("path");
global.sinon          = require('sinon');
global.chai           = require('chai');
global.expect         = chai.expect
global.srcDir         = path.join(__dirname, "../src")
global.discovery      = require(path.join(__dirname, "../discovery"))