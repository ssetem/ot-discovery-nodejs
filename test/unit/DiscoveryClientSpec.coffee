DiscoveryClient = require("#{srcDir}/DiscoveryClient")
ConsoleLogger = require("#{srcDir}/ConsoleLogger")
Promise = require "bluebird"

describe "DiscoveryClient", ->

  beforeEach ->
    Promise.promisifyAll(DiscoveryClient.prototype)
    @discoveryClient = new DiscoveryClient( testHosts.discoverRegionHost, testHosts.announceHosts,testHomeRegionName, testServiceName)


  it "should exist", ->
    expect(@discoveryClient).to.exist

  it "logger", ->
    expect(@discoveryClient.logger).to.equal ConsoleLogger



  it "make sure discovery can be promisified", ->
    expect(@discoveryClient.connectAsync).to.exist
    expect(@discoveryClient.announceAsync).to.exist
    expect(@discoveryClient.unannounceAsync).to.exist