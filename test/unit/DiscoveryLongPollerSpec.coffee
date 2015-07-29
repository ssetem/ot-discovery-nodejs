DiscoveryClient = require("#{srcDir}/DiscoveryClient")
Utils           = require("#{srcDir}/Utils")
nock            = require "nock"
_               = require "lodash"

describe "DiscoveryLongPoller", ->

  beforeEach ->
    nock.cleanAll()
    nock.disableNetConnect()
    @discoveryClient = new DiscoveryClient( testHosts.discoverRegionHost, testHosts.announceHosts,testHomeRegionName, testServiceName, {
      logger:
        logs:[]
        log:()->
          # console.log arguments
          @logs.push(arguments)
    })
    @logger = @discoveryClient.logger
    @poller = @discoveryClient.discoveryLongPoller

    @discoveryServer = "http://discover-server"
    @discoveryClient.reconnect = ->

    @discoveryClient.serverList.servers = [
      @discoveryServer
    ]

  afterEach ->
    nock.cleanAll()

  it "should exist", ->
    expect(@poller).to.exist


  describe "startPolling()", ->

    it "successful poll", (done)->

      r1 = nock(@discoveryServer)
        .get("/watch?clientServiceType=#{testServiceName}&since=0")
        .reply(200, {index:0})
      r2 = nock(@discoveryServer)
        .get("/watch?clientServiceType=#{testServiceName}&since=1")
        .reply(200, {index:1})
      r3 = nock(@discoveryServer)
        .get("/watch?clientServiceType=#{testServiceName}&since=2")
        .reply(204)
      r4 = nock(@discoveryServer)
        .get("/watch?clientServiceType=#{testServiceName}&since=2")
        .reply(200, {
          index:100
        })

      updates = []
      @discoveryClient.onUpdate (update)->
        updates.push(update)
        if update.index is 100
          r1.done()
          r2.done()
          r3.done()
          r4.done()
          expect(updates).to.deep.equal [
            { index: 0 }
            { index: 1 }
            { index: 100 }
          ]
          done()

      @poller.startPolling()

    it "no connect error remove server from rotation", (done)->
      errors = []
      @discoveryClient.onError (err)=>
        expect(err.name).to.equal(
          "NetConnectNotAllowedError")

        @poller.stopPolling()
        expect(@discoveryClient.getServers())
          .to.deep.equal []
        done()

      @poller.startPolling()







