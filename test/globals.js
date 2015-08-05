var path              = require("path");
global.sinon          = require('sinon');
global.chai           = require('chai');
global.expect         = chai.expect;
global.srcDir         = path.join(__dirname, "../src");
global.discovery      = require(path.join(__dirname, "../discovery"));
global.testHosts    = { 
                          discoverRegionHost: 'testhost',
                          announceHosts: ['testhost']
                        }
global.api2testHosts= { 
                          discoverRegionHost: 'testhost',
                          announceHosts: ['testhost', 'announcehost2']
                        }
global.testServiceName= "testServiceName"
global.testHomeRegionName= "testHomeRegionName"
global.testExternalRegionName = "testExternalRegionName"
