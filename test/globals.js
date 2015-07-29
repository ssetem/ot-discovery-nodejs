var path              = require("path");
global.sinon          = require('sinon');
global.chai           = require('chai');
global.expect         = chai.expect;
global.srcDir         = path.join(__dirname, "../src");
global.discovery      = require(path.join(__dirname, "../discovery"));
global.testHosts    = { 
                          discoverRegionHost: 'testHost',
                          announceHosts: ['testHost']
                        }
global.api2testHosts= { 
                          discoverRegionHost: 'testHost',
                          announceHosts: ['testHost', 'announceHost2']
                        }
global.testServiceName= "testServiceName"
global.testHomeRegionName= "testHomeRegionName"
global.testExternalRegionName = "testExternalRegionName"
