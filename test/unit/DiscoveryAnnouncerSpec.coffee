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
    beforeEach ->
      replaceMethod @announcer, 'updateHeartbeat'

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
      .then (result) =>
        expect(result).to.have.property('announcementId')
          .to.match(/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[89ab][0-9a-f]{3}-[0-9a-f]{12}/i)
        announcementId = result.announcementId
        expect(@logger.log.getCall(1).args).to.deep.equal [
          'debug',
          """Announcing to http://discover-server/announcement{"serviceType":"test","serviceUri":"test","announcementId":"#{announcementId}"}"""
        ]
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
        announcementRecord = _.find @announcer._announcedRecords, @announcement
        expect(@announcer.updateHeartbeat.called).to.be.ok
        expect(announcementRecord).to.be.ok
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
          expect(@announcer.updateHeartbeat.called).to.be.ok
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
          announcementRecord = _.find @announcer._announcedRecords, @announcement
          expect(announcementRecord).to.be.ok
          expect(@announcer.serverList.isEmpty).to.be.ok
          expect(@announcer.updateHeartbeat.called).to.be.ok
          expect(@logger.log.getCalls()[2].args).to.deep.equal  [
            'error',
            'Failure Announcing to http://discover-server/announcement{"announcementId":"a1","serviceType":"my-new-service","serviceUri":"http://my-new-service:8080"}'
            'rejection'
          ]
          done()


    it "announce() exceed request timeout", (done) ->
      @announcer.REQUEST_TIMEOUT_MS = 1000
      watch =
        nock @discoveryHost
          .get('/watch')
          .reply(200, @discoAnnouncements)

      delayedAnnouncement =
        nock(@discoveryServer)
          .post('/announcement', @announcement)
          .socketDelay(2000)
          .reply(200)

      @announcer.announce(@announcement)
        .catch (e) =>
          expect(e.message).to.equal "ESOCKETTIMEDOUT"
          expect(@announcer.serverList.servers).to.deep.equal []
          logs = _.pluck @logger.log.getCalls(), "args"
          expect(logs).deep.equal [
            [ 'info',  'Syncing discovery servers http://discover-server' ],
            [ 'debug', 'Announcing to http://discover-server/announcement{"announcementId":"a1","serviceType":"my-new-service","serviceUri":"http://my-new-service:8080"}' ],
            [ 'error', 'Failure Announcing to http://discover-server/announcement{"announcementId":"a1","serviceType":"my-new-service","serviceUri":"http://my-new-service:8080"}','ESOCKETTIMEDOUT' ],
            [ 'info', 'Dropping discovery server http://discover-server' ]
          ]
          done()

    it "watch fails status code", (done) ->
      watch =
        nock @discoveryHost
          .get('/watch')
          .reply(500)

      @announcer.announce(@announcement)
        .catch (e) =>
          expect(e).to.be.ok
          announcementRecord = _.find @announcer._announcedRecords, @announcement
          expect(announcementRecord).to.be.ok
          expect(@announcer.updateHeartbeat.called).to.be.ok
          watch.done()
          done()

    it "watch returns 204 instead of 200", (done) ->
      watch =
        nock @discoveryHost
          .get('/watch')
          .reply(204)

      @announcer.announce(@announcement)
        .catch (e) =>
          expect(e).to.be.ok
          announcementRecord = _.find @announcer._announcedRecords, @announcement
          expect(announcementRecord).to.be.ok
          expect(@announcer.updateHeartbeat.called).to.be.ok
          watch.done()
          done()

    it "watch rejects", (done) ->
      watch =
        nock @discoveryHost
          .get('/watch')
          .replyWithError('rejection')

      @announcer.announce(@announcement)
        .catch (e) =>
          expect(e).to.be.ok
          announcementRecord = _.find @announcer._announcedRecords, @announcement
          expect(announcementRecord).to.be.ok
          expect(@announcer.updateHeartbeat.called).to.be.ok
          watch.done()
          done()

  describe "pingAllAnnouncements", () ->
    beforeEach ->
      # in this test, we won't test the server list / watch which is tested
      # in the suite for 'announce'
      @announcer.serverList.addServers [@discoveryServer]
      @announcer._announcedRecords[@announcement.announcementId] = @announcement
      @announcement2 =
        announcementId: "a2"
        serviceType: "my-other-service"
        serviceUri: "http://my-other-service"
      @announcer._announcedRecords[@announcement2.announcementId] = @announcement2

    it "pingAllAnnouncements - success", (done) ->
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

    it "pingAllAnnouncements - failure", (done) ->
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

    it "pingAllAnnouncements - success after an announce failure", (done) ->
      @announcer._announcedRecords = {} #clear all the announcements we mocked
      delete @announcement.announcementId

      @first = true
      announce =
        nock @discoveryServer
          .post '/announcement'
          .reply 500, "failed"
      success =
        nock @discoveryServer
          .post '/announcement'
          .reply (uri, body) ->
            [201, body]

      # so we don't have to mess with stopping the heartbeat later
      # the call itself is tested in `announce` test suite above
      replaceMethod @announcer, 'updateHeartbeat'

      @announcer.announce(@announcement)
        .then () ->
          done new Error("should have failed")
        .catch (e) =>
          #the server failed so it was dropped. add it back again
          @announcer.serverList.addServers [@discoveryServer]

          @announcer.pingAllAnnouncements().then (announced) =>
            expect(_.find(announced, @announcement)).to.be.ok
            announce.done()
            success.done()
          .then(done).catch(done)

  describe "unannounce", () ->
    beforeEach ->
      # in this test, we won't test the server list / watch which is tested
      # in the suite for 'announce'
      @announcer.serverList.addServers [@discoveryServer]
      @announcer._announcedRecords[@announcement.announcementId] = @announcement
      replaceMethod @announcer, 'updateHeartbeat'

    it "unannounce - error - rejection", (done) ->
      unannounce =
        nock(@discoveryServer)
          .delete('/announcement/a1')
          .replyWithError('rejection')

      @announcer.unannounce(@announcement).catch (e) =>
        expect(e).to.be.ok
        expect(@announcer.updateHeartbeat.called).to.not.be.ok
        unannounce.done()
        done()

    it "unannouce - status code - error", (done) ->
      unannounce =
        nock(@discoveryServer)
          .delete('/announcement/a1')
          .reply(500)

      @announcer.unannounce(@announcement).catch (e) =>
        expect(e).to.be.ok
        expect(@announcer.updateHeartbeat.called).to.not.be.ok
        unannounce.done()
        done()

    it "unannounce - success", (done)->
      unannounceRequest = nock(@discoveryServer)
        .delete("/announcement/a1")
        .reply(200)
      @announcer.unannounce(@announcement).then () =>
        expect(@announcer.updateHeartbeat.called).to.be.ok
        done()
      .catch(done)

    it "unannounce - does nothing", (done) ->
      @announcer._announcedRecords = {}
      # any actual HTTP request here will cause nock to throw an rejection
      @announcer.unannounce(@announcement).then () =>
        expect(@announcer.updateHeartbeat.called).to.not.be.ok
        done()
      .catch(done)

    it "unannounce - fail then success then nothing", (done) ->
      fail = nock @discoveryServer
        .delete "/announcement/a1"
        .reply 500

      success = nock @discoveryServer
        .delete "/announcement/a1"
        .reply 200

      @announcer.unannounce(@announcement).then () ->
        done new Error("should not get here")
      .catch (e) =>
        #it was dropped; readd it so we don't have to mock disco-request
        @announcer.serverList.addServers [@discoveryServer]
        expect(@announcer.updateHeartbeat.called).to.not.be.ok
        @announcer.updateHeartbeat.reset()

        @announcer.unannounce(@announcement)
          .then () =>
            expect(@announcer.updateHeartbeat.called).to.be.ok
            @announcer.updateHeartbeat.reset()
            @announcer.unannounce(@announcement)
          .then () =>
            expect(@announcer.updateHeartbeat.called).to.not.be.ok
            fail.done()
            success.done()
            done()
          .catch done

  describe "heartbeats", ->
    before ->
      @clock = sinon.useFakeTimers()

    beforeEach ->
      replaceMethod @announcer, 'pingAllAnnouncements'

    afterEach ->
      @announcer.stopHearbeat

    after ->
      @clock.restore()

    it "no entries - does nothing", ->
      @announcer.updateHeartbeat

      @clock.tick @announcer.HEARTBEAT_INTERVAL_MS + 1
      expect(@announcer.pingAllAnnouncements.called).to.not.be.ok

    it "1 entry - heart beats", ->
      @announcer._announcedRecords = {1: {}}
      @announcer.updateHeartbeat()

      @clock.tick @announcer.HEARTBEAT_INTERVAL_MS + 1
      expect(@announcer.pingAllAnnouncements.called).to.be.ok
      @announcer.pingAllAnnouncements.reset()

      @clock.tick @announcer.HEARTBEAT_INTERVAL_MS + 1
      expect(@announcer.pingAllAnnouncements.called).to.be.ok

    it "1 entry - called twice - only 1 announcement per interval", ->
      @announcer._announcedRecords = {1: {}}
      @announcer.updateHeartbeat()
      @announcer.updateHeartbeat()

      @clock.tick @announcer.HEARTBEAT_INTERVAL_MS + 1
      expect(@announcer.pingAllAnnouncements.callCount).to.equal 1
      @announcer.pingAllAnnouncements.reset()

      @clock.tick @announcer.HEARTBEAT_INTERVAL_MS + 1
      expect(@announcer.pingAllAnnouncements.callCount).to.equal 1

    it "stops heartbeat if drops to 0 entries", ->
      @announcer._announcedRecords = {1: {}}
      @announcer.updateHeartbeat()

      @clock.tick @announcer.HEARTBEAT_INTERVAL_MS + 1
      expect(@announcer.pingAllAnnouncements.called).to.be.ok

      @announcer.pingAllAnnouncements.reset()
      @announcer._announcedRecords = {}
      @announcer.updateHeartbeat()

      @clock.tick @announcer.HEARTBEAT_INTERVAL_MS + 1

      expect(@announcer.pingAllAnnouncements.called).to.not.be.ok
      @announcer.updateHeartbeat()

      @clock.tick @announcer.HEARTBEAT_INTERVAL_MS + 1
      expect(@announcer.pingAllAnnouncements.called).to.not.be.ok

    it "restarts heartbeat", ->
      @announcer._announcedRecords = {1: {}}
      @announcer.updateHeartbeat()
      @clock.tick @announcer.HEARTBEAT_INTERVAL_MS + 1
      expect(@announcer.pingAllAnnouncements.called).to.be.ok

      @announcer.pingAllAnnouncements.reset()
      @announcer._announcedRecords = {}
      @announcer.updateHeartbeat()

      @clock.tick @announcer.HEARTBEAT_INTERVAL_MS + 1

      expect(@announcer.pingAllAnnouncements.called).to.not.be.ok

      @announcer._announcedRecords = {1: {}}
      @announcer.updateHeartbeat()
      @clock.tick @announcer.HEARTBEAT_INTERVAL_MS + 1
      expect(@announcer.pingAllAnnouncements.called).to.be.ok
