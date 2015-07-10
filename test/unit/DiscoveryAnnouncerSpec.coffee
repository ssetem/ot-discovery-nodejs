DiscoveryClient = require("#{srcDir}/DiscoveryClient")
nock = require "nock"

describe "DiscoveryAnnouncer", ->

  beforeEach ->
    nock.cleanAll();
    nock.disableNetConnect();
    @discoveryClient = new DiscoveryClient("discovery.com", {
      logger:
        logs:[]
        log:()->
          # console.log arguments
          @logs.push(arguments)
    })
    @logger = @discoveryClient.logger
    @announcer = @discoveryClient.discoveryAnnouncer

    @discoveryServer = "http://discover-server"
    @discoveryClient.serverList.servers = [
      @discoveryServer
    ]
    @announcement = {
      announcementId:"a1"
      serviceType : "my-new-service",
      serviceUri  : "http://my-new-service:8080"
    }

  it "should exist", ->
    expect(@announcer).to.exist



  describe "announce", ->

    it "announce() success after 5 failures", (done)->

      self = @
      @announcer.INITIAL_BACKOFF = 1
      @announcer.ANNOUNCE_ATTEMPTS = 10
      initialFailure =
        nock(@discoveryServer)
          .post('/announcement', @announcement)
          .times(5)
          .reply(400, "Simulated error")
      success =
        nock(@discoveryServer)
          .post('/announcement', @announcement)
          .reply(201, @announcement)

      @announcer.announce(@announcement)
        .then (result)=>
          expect(result).to.deep.equal @announcement
          initialFailure.done()
          success.done()
          expect(@announcer.announcements["a1"])
            .to.deep.equal @announcement
          done()
    it "announce() error after 5 failures", (done)->

      self = @
      @announcer.INITIAL_BACKOFF = 1
      @announcer.ANNOUNCE_ATTEMPTS = 4
      initialFailure =
        nock(@discoveryServer)
          .post('/announcement', @announcement)
          .times(5)
          .reply(400, "Simulated error")


      @announcer.announce(@announcement)
        .catch (e)=>
          initialFailure.done()
          expect(e.message).to.equal 'During announce, bad status code 400:"Simulated error"'
          expect(@discoveryClient.getServers().length).to.equal 1
          done()

    it "announce() no connect removes server out of rotation", (done)->

      self = @
      @announcer.INITIAL_BACKOFF = 1
      @announcer.ANNOUNCE_ATTEMPTS = 1


      @announcer.announce(@announcement)
        .catch (e)=>
          expect(e.message).to.equal(
            "Cannot announce. No discovery servers available")
          expect(@discoveryClient.getServers().length).to.equal 0
          done()

  describe "pingAllAnnouncements, unnannounce", ->
    beforeEach ->
      @announcer.announcements =
        "a1":
          announcementId:"a1"
          serviceType : "my-new-service",
          serviceUri  : "http://my-new-service:8080"
        "a2":
          announcementId:"a2"
          serviceType : "my-new-service",
          serviceUri  : "http://my-new-service2:8080"
      {@a1, @a2} = @announcer.announcements

    it "pingAllAnnouncements - success", (done)->


      a1Request =
        nock(@discoveryServer)
          .post('/announcement', @a1)
          .reply(201, @a1)

      a2Request =
        nock(@discoveryServer)
          .post('/announcement', @a2)
          .reply(201, @a2)

      @announcer.pingAllAnnouncements().then (result)=>
          expect(result).to.deep.equal [@a1,@a2]
          a1Request.done()
          a2Request.done()
          done()

    it "pingAllAnnouncements - failure", (done)->
      a1Request =
        nock(@discoveryServer)
          .post('/announcement', @a1)
          .reply(400, "Announce error")

      a2Request =
        nock(@discoveryServer)
          .post('/announcement', @a2)
          .reply(400,"Announce error")

      @announcer.pingAllAnnouncements().catch (e)->
        a1Request.done()
        a2Request.done()
        expect(e.message).to.equal(
          'During announce, bad status code 400:"Announce error"')
        done()


    it "unannounce - error - no connect", (done)->
      @announcer.unannounce(@a1).catch (e)=>
        expect(e.name).to.equal "NetConnectNotAllowedError"
        expect(@announcer.announcements.a1)
          .to.equal undefined
        done()


    it "unannounce - success", (done)->
      unannounceRequest = nock(@discoveryServer)
        .delete("/announcement/a1")
        .reply(200)
      @announcer.unannounce(@a1).then (result)=>
        expect(@logger.logs[0][0]).to.equal 'info'
        expect(@logger.logs[0][1]).to.equal(
          'Unannounce DELETE \'http://discover-server/announcement/a1\' returned 200:""')
        done()


