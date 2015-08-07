DiscoveryAnnouncer = require("#{srcDir}/DiscoveryAnnouncer")
nock = require "nock"
_ = require "lodash"
sinon = require "sinon"
Promise = require "bluebird"

describe "DiscoveryAnnouncer", ->
  beforeEach ->
    nock.cleanAll()
    nock.disableNetConnect()
    @logger =
      log: sinon.spy()

    @discoveryHost = "discover-host"
    @discoveryServer = "http://discover-server"
    @discoveryNotifier =
      notifyAndReject: sinon.spy (err) ->
        return Promise.reject err

    @announcer = new DiscoveryAnnouncer(@logger, @discoveryHost, @discoveryNotifier)
    @announcer.INITIAL_BACKOFFS = 1

    @discoAnnouncements =
      updates: [
        {
          announcementId:"disco"
          serviceType : "discovery"
          serviceUri  : @discoveryServer
        }
      ]

    @announcement = {
      announcementId:"a1"
      serviceType : "my-new-service",
      serviceUri  : "http://my-new-service:8080"
    }

  describe "announce", ->
    it "announce() success after failure", (done) ->
      watch =
        nock("http://#{@discoveryHost}")
          .get('/watch')
          .reply(200, @discoAnnouncements)

      initialFailure =
        nock(@discoveryServer)
          .post('/announcement', @announcement)
          .reply(400, "Simulated error")

      success =
        nock(@discoveryServer)
          .post('/announcement', @announcement)
          .reply(201, @announcement)

      @announcer.announce(@announcement).then (result) =>
        expect(result).to.deep.equal @announcement
        done()

    it "announce() error after max failure", (done)->
      @announcer.ANNOUNCED_ATTEMPTS = 0
      watch =
        nock("http://#{@discoveryHost}")
          .get('/watch')
          .reply(200, @discoAnnouncements)

      initialFailure =
        nock(@discoveryServer)
          .post('/announcement', @announcement)
          .reply(400, "Simulated error")

      @announcer.announce(@announcement)
        .catch (e) ->
          expect(e.message).to.equal 'During announce, bad status code 400:"Simulated error"'
          done()

    it "announce() failure removes server out of rotation", (done)->
      watch =
        nock("http://#{@discoveryHost}")
          .get('/watch')
          .reply(200, @discoAnnouncements)

      initialFailure =
        nock(@discoveryServer)
          .post('/announcement', @announcement)
          .reply(400, "Simulated error")

      @announcer.ANNOUNCED_ATTEMPTS = 0

      @announcer.announce(@announcement)
        .catch (e)=>
          expect(@announcer.serverList.isEmpty).to.be.ok
          done()

    it "all servers removed forces a rewatch", (done) ->
      done()

    it "watch fails forces a reattempt", (done) ->
      watch =
        nock("http://#{@discoveryHost}")
          .get('/watch')
          .times(5)
          .reply(500)

      @announcer.ANNOUNCED_ATTEMPTS = 5
      @announcer.announce(@announcement)
        .catch (e) ->
          expect(e).to.be.ok
          done()

  describe "pingAllAnnouncements", () ->
    beforeEach ->
      # in this test, we won't test the server list / watch which is tested
      # in the suite for 'announce'
      @announcer.serverList.addServers [@discoveryServer]
      @announcer._doAddAnnouncement @announcement
      @announcement2 =
        announcementId: "a2"
        serviceType: "my-other-service"
        serviceUri: "http://my-other-service"
      @announcer._doAddAnnouncement @announcement2

    it "pingAllAnnouncements - success", (done)->
      a1Request =
        nock(@discoveryServer)
          .post('/announcement', @announcement)
          .reply(201, @announcement)

      a2Request =
        nock(@discoveryServer)
          .post('/announcement', @announcement2)
          .reply(201, @announcement2)

      @announcer.pingAllAnnouncements().then (announced) =>
        expect(announced).to.deep.equal([@announcement, @announcement2])
        done()

    it "pingAllAnnouncements - failure", (done)->
      #test that even if one fails the entire thing succeeds
      a1Request =
        nock(@discoveryServer)
          .post('/announcement', @announcement)
          .reply(400, "Announce error")

      a2Request =
        nock(@discoveryServer)
          .post('/announcement', @announcement2)
          .reply(201, @announcement2)

      @announcer.pingAllAnnouncements().then (announced) =>
        expect(announced).to.deep.equal([@announcement2])
        expect(@logger.log.calledWith('error', '1 announcements failed')).to.be.ok
        done()

  describe "unannounce", () ->
    beforeEach ->
      # in this test, we won't test the server list / watch which is tested
      # in the suite for 'announce'
      @announcer.serverList.addServers [@discoveryServer]
      @announcer._doAddAnnouncement @announcement

    it "unannounce - error - no connect", (done) ->
      @announcer.unannounce(@announcement).catch (e) ->
        expect(e).to.be.ok
        done()

    it "unannounce - success", (done)->
      unannounceRequest = nock(@discoveryServer)
        .delete("/announcement/a1")
        .reply(200)
      @announcer.unannounce(@announcement).then (result) ->
        done()

  describe "heartbeats", () ->
    before () ->
      @clock = sinon.useFakeTimers()

    beforeEach () ->
      @announcer.pingAllAnnouncements = sinon.spy()

    after () ->
      @clock.restore()

    it "starts heartbeat", () ->
      @announcer.startAnnouncementHeartbeat()
      @clock.tick(@announcer.HEARTBEAT_INTERVAL_MS + 1)
      expect(@announcer.pingAllAnnouncements.called).to.be.ok
      @clock.tick(@announcer.HEARTBEAT_INTERVAL_MS + 1)
      expect(@announcer.pingAllAnnouncements.called).to.be.ok

    it "stops heartbeat", () ->
      @announcer.stopAnnouncementHeartbeat()
      @announcer.startAnnouncementHeartbeat()
      @announcer.stopAnnouncementHeartbeat()
      @clock.tick(@announcer.HEARTBEAT_INTERVAL_MS + 1)
      expect(@announcer.pingAllAnnouncements.called).to.not.be.ok
