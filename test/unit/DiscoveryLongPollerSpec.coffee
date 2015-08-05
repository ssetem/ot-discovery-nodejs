DiscoveryLongPoller = require("#{srcDir}/DiscoveryLongPoller")
ServerList = require "#{srcDir}/ServerList"
AnnouncementIndex = require "#{srcDir}/AnnouncementIndex"
Utils           = require("#{srcDir}/Utils")
nock            = require "nock"
_               = require "lodash"
sinon = require "sinon"

describe.only "DiscoveryLongPoller", ->

  beforeEach ->
    nock.cleanAll()
    nock.disableNetConnect()
    # @discoveryClient = new DiscoveryClient( testHosts.discoverRegionHost, testHosts.announceHosts,testHomeRegionName, testServiceName, {
    #   logger:
    #     logs:[]
    #     log:()->
    #       # console.log arguments
    #       @logs.push(arguments)
    # })
    @logger = 
      log: () -> 
    @serverList = new ServerList @logger
    @announcementIndex = 
      processUpdate: (item) ->
        @announcementIndex.index = item.index
      index: -1
    @discoveryNotifier = 
      notifyError: (error) ->
        console.log "GOT ERROR", error
    @discoveryLongPoller = new DiscoveryLongPoller testServiceName, @serverList, @announcementIndex, @discoveryNotifier, () -> 
    
    @discoveryServer = "http://discover-server"
    @serverList.addServers [@discoveryServer]

  afterEach ->
    nock.cleanAll()

  describe "startPolling()", ->
    it "successful poll", (done)->
      r1 = nock(@discoveryServer)
        .filteringPath (path)->
          console.log "PATH IS:", path
        .get("/watch?since=0&clientServiceType=#{testServiceName}")
        .reply(200, {index:0})
      r2 = nock(@discoveryServer)
        .get("/watch?since=1&clientServiceType=#{testServiceName}")
        .reply(200, {index:1})
      r3 = nock(@discoveryServer)
        .get("/watch?since=2&clientServiceType=#{testServiceName}")
        .reply(204)
      r4 = nock(@discoveryServer)
        .get("/watch?since=2&clientServiceType=#{testServiceName}")
        .reply(200, {
          index:100
        })

      updates = []
      @announcementIndex.processUpdate = sinon.spy (update) =>
        console.log "SETTING INDEX TO:", update.index
        @announcementIndex.index = update.index
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

      @discoveryLongPoller.startPolling()

    it "no connect error remove server from rotation", (done)->
      errors = []
      @discoveryNotifier.notifyError = (err)=>
        expect(err.name).to.equal(
          "NetConnectNotAllowedError")

        @discoveryLongPoller.stopPolling()
        expect(@serverList.isEmpty())
          .to.be.true
        done()

      @discoveryLongPoller.startPolling()

    it "should not called announcementIndex.update on 204", (done) ->
      expect(false)
      done()





