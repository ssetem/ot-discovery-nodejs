DiscoveryLongPoller = require("#{srcDir}/DiscoveryLongPoller")
ServerList = require "#{srcDir}/ServerList"
AnnouncementIndex = require "#{srcDir}/AnnouncementIndex"
Utils           = require("#{srcDir}/Utils")
nock            = require "nock"
_               = require "lodash"
sinon = require "sinon"

describe "DiscoveryLongPoller", ->

  beforeEach ->
    nock.cleanAll()
    nock.disableNetConnect()

    @logger =
      log: () ->
    @serverList = new ServerList @logger
    @announcementIndex =
      processUpdate: sinon.spy()

    @discoveryNotifier =
      notifyError: sinon.spy (error) ->
        Promise.reject(error)

    @reconnect = sinon.spy()

    @discoveryLongPoller = new DiscoveryLongPoller testServiceName, @serverList, @announcementIndex, @discoveryNotifier, @reconnect

    @discoveryServer = "http://discover-server"
    @serverList.addServers [@discoveryServer]

  afterEach ->
    nock.cleanAll()

  describe "start polling", ->
    it "starts polling with a server", ->
      @discoveryLongPoller.schedulePoll = sinon.spy()
      @discoveryLongPoller.startPolling()
      expect(@discoveryLongPoller.schedulePoll.called).to.be.ok

    it "calls reconnect without a server", ->
      @serverList.dropServer @discoveryServer
      @discoveryLongPoller.startPolling()
      expect(@reconnect.called).to.be.ok

  it "stop polls", (done) ->
    this.timeout(500)

    @announcementIndex.index = 1
    longPoll = nock(@discoveryServer)
      .get("/watch?since=2&clientServiceType=#{testServiceName}")
      .reply () ->
        setTimeout () ->
          done new Error('not called')
        , 1000

    @discoveryLongPoller.poll()
    setTimeout () =>
      @discoveryLongPoller.stopPolling()
      process.nextTick () ->
        longPoll.done()
        done()
    , 100

  describe "polling", ->
    beforeEach ->
      @discoveryLongPoller.shouldBePolling = true

    it "calls process if 200", (done) ->
      @announcementIndex.index = 1
      nock(@discoveryServer)
        .get("/watch?since=2&clientServiceType=#{testServiceName}")
        .reply(200)

      @discoveryLongPoller.schedulePoll = () ->
        expect(@announcementIndex.processUpdate.called).to.be.ok
        done()

      @discoveryLongPoller.poll()

    it "calls nothing if 204", (done) ->
      @announcementIndex.index = 1
      nock(@discoveryServer)
        .get("/watch?since=2&clientServiceType=#{testServiceName}")
        .reply(204)

      @announcementIndex.processUpdate = () ->
        done new Error('should not be called')

      @discoveryLongPoller.schedulePoll = done

      @discoveryLongPoller.poll()

    it "drops the server if bad", (done) ->
      @announcementIndex.index = 1
      nock(@discoveryServer)
        .get("/watch?since=2&clientServiceType=#{testServiceName}")
        .reply(500)

      @discoveryLongPoller.poll()
      @discoveryNotifier.notifyError = () =>
        expect(@serverList.isEmpty).to.be.ok
        done()

    it "reschedules a poll", (done) ->
      @announcementIndex.index = 1
      nock(@discoveryServer)
        .get("/watch?since=2&clientServiceType=#{testServiceName}")
        .reply(204)
      @discoveryLongPoller.schedulePoll = done
      @discoveryLongPoller.poll()

    it "always uses the next index", (done) ->
      @announcementIndex.index = 100
      nock(@discoveryServer)
        .get("/watch?since=101&clientServiceType=#{testServiceName}")
        .reply(204)
      @discoveryLongPoller.handleResponse = () =>
        done()
      @discoveryLongPoller.poll()
