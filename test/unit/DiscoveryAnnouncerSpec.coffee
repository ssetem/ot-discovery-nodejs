DiscoveryAnnouncer = require "#{srcDir}/DiscoveryAnnouncer"
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

    @discoveryHost = "http://discover-host"
    @discoveryServer = "http://discover-server"

    @announcer = new DiscoveryAnnouncer @logger, "discover-host"

    @discoAnnouncements =
      fullUpdate: true
      updates: [
        {
          announcementId:"disco"
          serviceType : "discovery"
          serviceUri  : @discoveryServer
        },
        {
          announcementId:"other"
          serviceType : "other"
          serviceUri  : "foobar"
        },
      ]

    @announcement = {
      announcementId:"a1"
      serviceType : "my-new-service",
      serviceUri  : "http://my-new-service:8080"
    }

  describe "connect", ->
    it "calls watcher.connect and plucks disco only", (done) ->
      watch =
        nock @discoveryHost
          .get('/watch')
          .reply(200, @discoAnnouncements)

      @announcer.connect().then (servers) =>
        expect(servers).to.deep.equal [@discoveryServer]
        watch.done()
        done()

  describe "announce", ->
    it "sets a uuid if not there", (done) ->
      watch =
        nock @discoveryHost
          .get('/watch')
          .reply(200, @discoAnnouncements)

      success =
        nock(@discoveryServer)
          .post('/announcement')
          .reply (uri, requestBody) ->
            announcementRequest = JSON.parse requestBody
            expect(announcementRequest.serviceType).to.equal "test"
            expect(announcementRequest.serviceUri).to.equal "test"
            expect(announcementRequest.announcementId).to.be.ok
            [201, announcementRequest]

      @announcer.announce
        serviceType: "test"
        serviceUri: "test"
      .then (result) ->
        expect(result).to.have.property('announcementId')
          .to.match(/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[89ab][0-9a-f]{3}-[0-9a-f]{12}/i)
        done()

    it "announce() success", (done) ->
      watch =
        nock @discoveryHost
          .get('/watch')
          .reply(200, @discoAnnouncements)

      success =
        nock(@discoveryServer)
          .post('/announcement', @announcement)
          .reply(201, @announcement)

      @announcer.announce(@announcement).then (result) =>
        watch.done()
        success.done()
        expect(result).to.deep.equal @announcement
        return
      .then(done).catch(done)

    it "announce() status code error", (done) ->
      watch =
        nock @discoveryHost
          .get('/watch')
          .reply(200, @discoAnnouncements)

      failure =
        nock(@discoveryServer)
          .post('/announcement', @announcement)
          .reply(400, "Simulated error")

      @announcer.announce(@announcement)
        .catch (e) =>
          watch.done()
          failure.done()
          expect(e.message).to.equal 'During announce, bad status code 400:"Simulated error"'
          expect(@announcer.serverList.isEmpty).to.be.ok
          done()

    it "announce() rejects", (done) ->
      watch =
        nock @discoveryHost
          .get('/watch')
          .reply(200, @discoAnnouncements)

      failure =
        nock(@discoveryServer)
          .post('/announcement', @announcement)
          .replyWithError('rejection')

      @announcer.announce(@announcement)
        .catch (e) =>
          watch.done()
          failure.done()
          expect(e).to.be.ok
          expect(@announcer.serverList.isEmpty).to.be.ok
          done()

    it "watch fails status code", (done) ->
      watch =
        nock @discoveryHost
          .get('/watch')
          .reply(500)

      @announcer.announce(@announcement)
        .catch (e) ->
          expect(e).to.be.ok
          watch.done()
          done()

    it "watch returns 204 instead of 200", (done) ->
      watch =
        nock @discoveryHost
          .get('/watch')
          .reply(204)

      @announcer.announce(@announcement)
        .catch (e) ->
          expect(e).to.be.ok
          watch.done()
          done()

    it "watch rejects", (done) ->
      watch =
        nock @discoveryHost
          .get('/watch')
          .replyWithError('rejection')

      @announcer.announce(@announcement)
        .catch (e) ->
          expect(e).to.be.ok
          watch.done()
          done()

  describe "pingAllAnnouncements", () ->
    beforeEach ->
      # in this test, we won't test the server list / watch which is tested
      # in the suite for 'announce'
      @announcer.serverList.addServers [@discoveryServer]
      @announcer.handleResponse {statusCode:201}, @announcement
      @announcement2 =
        announcementId: "a2"
        serviceType: "my-other-service"
        serviceUri: "http://my-other-service"
      @announcer.handleResponse {statusCode:201}, @announcement2

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
        return
      .then(done).catch(done)

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
        return
      .then(done).catch(done)

  describe "unannounce", () ->
    beforeEach ->
      # in this test, we won't test the server list / watch which is tested
      # in the suite for 'announce'
      @announcer.serverList.addServers [@discoveryServer]
      @announcer.handleResponse {statusCode: 201}, @announcement

    it "unannounce - error - rejection", (done) ->
      unannounce =
        nock(@discoveryServer)
          .delete('/announcement/a1')
          .replyWithError('rejection')

      @announcer.unannounce(@announcement).catch (e) ->
        expect(e).to.be.ok
        unannounce.done()
        done()

    it "unannouce - status code - error", (done) ->
      unannounce =
        nock(@discoveryServer)
          .delete('/announcement/a1')
          .reply(500)

      @announcer.unannounce(@announcement).catch (e) ->
        expect(e).to.be.ok
        unannounce.done()
        done()

    it "unannounce - success", (done)->
      unannounceRequest = nock(@discoveryServer)
        .delete("/announcement/a1")
        .reply(200)
      @announcer.unannounce(@announcement).then (result) ->
        done()
      .catch(done)

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
