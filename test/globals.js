var path              = require("path");
global.sinon          = require('sinon');
global.chai           = require('chai');
global.expect         = chai.expect;
global.srcDir         = path.join(__dirname, "../src");
global.api2testHosts = { 
  discoverRegionHost: 'testhost',
  announceHosts: ['testhost', 'announcehost2']
};
global.replaceMethod = require('./helper').replaceMethod;
