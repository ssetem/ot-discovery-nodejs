DiscoveryClient = require("#{srcDir}/DiscoveryClient")
ConsoleLogger = require("#{srcDir}/ConsoleLogger")


describe "DiscoveryClient", ->

  beforeEach ->
    @discoveryClient = new DiscoveryClient("host")


  it "should exist", ->
    expect(@discoveryClient).to.exist

  it "logger", ->
    expect(@discoveryClient.logger).to.equal ConsoleLogger

