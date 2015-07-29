DiscoveryClient = require("#{srcDir}/DiscoveryClient")
nock = require "nock"
fs = require 'fs'

describe "DiscoveryAnnouncer api v2", ->
  beforeEach ->
    nock.cleanAll()
    nock.disableNetConnect()
    @discoveryClient = new DiscoveryClient( testHosts.discoverRegionHost, testHosts.announceHosts,testHomeRegionName, testServiceName, {
      logger:
        logs:[]
        log:(args...)->
          # console.log arguments
          args = args.map (arg)->
            arg.toString()
          @logs.push(args)
    })
    @logger = @discoveryClient.logger
    @announcer = @discoveryClient.discoveryAnnouncer

    @discoveryServer = "http://discover-server.com"
    @externalDiscoServer = "http://second-disco-server.com"
    @discoveryClient.serverList.servers = [
      @discoveryServer
    ]
    @discoveryClient.regions[api2testHosts.announceRegions[1]].serverList.servers = [
      @externalDiscoServer
    ]

    @announcement = {
      announcementId: "announcementId1",
      serviceType : "my-new-service",
      serviceUri  : "http://my-new-service:8080"
      environment : api2testHosts.announceRegions[0]
    }
    @announcement2 = {
      announcementId: "announcementId2",
      serviceType : "my-new-service",
      serviceUri  : "http://my-new-service:8080"
      environment : api2testHosts.announceRegions[1]
    }

  describe "announce", ->
    it "should annoucne() at both endpoints", (done)->
      self = @
      success =
        nock(@discoveryServer)
          .post('/announcement', () ->
            return true
          )
          .reply(201, (url, requestBody) =>
            return @announcement
          )
      success2 =
        nock(@externalDiscoServer)
          .post('/announcement', () ->
            return true
          )
          .reply(201, (url, requestBody) =>
            return @announcement2
          )
      @discoveryClient.announce @announcement, (result) =>
        success.done()
        success2.done()
        #expect(@announcer.announcements[@announcement.announcementId])
        #  .to.deep.equal @announcement
        done()