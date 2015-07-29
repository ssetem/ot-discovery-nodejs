DiscoveryClient = require("#{srcDir}/DiscoveryClient")
nock = require "nock"
_ = require "lodash"

describe "DiscoveryAnnouncer", ->

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

    @discoveryServer = "http://discover-server"
    @discoveryClient.serverList.servers = [
      @discoveryServer
    ]
    @announcement = {
      announcementId:"a1"
      serviceType : "my-new-service",
      serviceUri  : "http://my-new-service:8080"
    }

  afterEach ->
    @announcer.resetRetryCounts()

  it "should exist", ->
    expect(@announcer).to.exist

  describe "announce", ->

    it "announce() success after 5 failures", (done)->
      self = @
      @announcer.setAnnouceAttemptsCount 10
      @announcer.setInitialBackoffCount 1
      # adding envrionment to announcement because that's auto-added by the disco library
      returnedAnnouncement = _.extend @announcement, {environment: testHomeRegionName}
      initialFailure =
        nock(@discoveryServer)
          .post('/announcement', @announcement)
          .times(5)
          .reply(400, "Simulated error")
      success =
        nock(@discoveryServer)
          .post('/announcement', @announcement)
          .reply(201, returnedAnnouncement)

      @discoveryClient.announce @announcement, (result) =>
        #expect(result).to.deep.equal @announcement
        process.nextTick () =>
          try
            initialFailure.done()
            success.done()
            expect(@discoveryClient.getAnnouncements()["a1"])
              .to.deep.equal @announcement
            done()
          catch err 
            console.trace "SUCCESS after 5 FAILURES TEST CAUGHT AN ERROR!!!!!", err

    it "announce() error after 5 failures", (done)->
      self = @
      @announcer.setInitialBackoffCount 1
      @announcer.setAnnouceAttemptsCount 4
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
      @announcer.setInitialBackoffCount 1
      @announcer.setAnnouceAttemptsCount 1


      @announcer.announce(@announcement)
        .catch (e)=>
          expect(e.message).to.equal(
            "Cannot announce. No discovery servers available")
          expect(@discoveryClient.getServers().length).to.equal 0
          done()

  describe "pingAllAnnouncements, unnannounce", ->
    beforeEach ->
      @discoveryClient.discoveryAnnouncer._doAddAnnouncement 
        announcementId:"a1"
        serviceType : "my-new-service",
        serviceUri  : "http://my-new-service:8080"
        environment : testHomeRegionName

      @discoveryClient.discoveryAnnouncer._doAddAnnouncement 
        announcementId:"a2"
        serviceType : "my-new-service",
        serviceUri  : "http://my-new-service2:8080"
        environment : testExternalRegionName

      as = @discoveryClient.getAnnouncements()
      {@a1, @a2} = @discoveryClient.getAnnouncements()

    it "pingAllAnnouncements - success", (done)->
      a1Request =
        nock(@discoveryServer)
          .post('/announcement', @a1)
          .reply(201, @a1)

      a2Request =
        nock(@discoveryServer)
          .post('/announcement', @a2)
          .reply(201, @a2)

      @discoveryClient.discoveryAnnouncer.pingAllAnnouncements().then (result)=>
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

      @discoveryClient.discoveryAnnouncer.pingAllAnnouncements().then ()=>
        a1Request.done()
        a2Request.done()
        expect(@logger.logs).to.deep.equal [
          [ 'debug',
            'Announcing {"announcementId":"a1","serviceType":"my-new-service","serviceUri":"http://my-new-service:8080","environment":"prod-uswest2"}' ]
          [ 'debug',
            'Announcing {"announcementId":"a2","serviceType":"my-new-service","serviceUri":"http://my-new-service2:8080","environment":"prod-uswest2"}' ],
          [ 'error',
            'Discovery error: ',
            'Error: During announce, bad status code 400:"Announce error"' ],
          [ 'error',
            'Discovery error: ',
            'Error: During announce, bad status code 400:"Announce error"' ],
          [ 'error', '2 announcements failed' ] ]
        done()


    it "unannounce - error - no connect", (done)->
      @announcer.unannounce(@a1).catch (e)=>
        expect(e.name).to.equal "NetConnectNotAllowedError"
        expect(@discoveryClient.getAnnouncements().a1)
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


