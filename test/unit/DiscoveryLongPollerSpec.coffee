DiscoveryLongPoller = require("#{srcDir}/DiscoveryLongPoller")
ServerList = require "#{srcDir}/ServerList"
AnnouncementIndex = require "#{srcDir}/AnnouncementIndex"
Utils           = require("#{srcDir}/Utils")
nock            = require "nock"
_               = require "lodash"
sinon = require "sinon"
Promise = require "bluebird"

describe "DiscoveryLongPoller", ->

  beforeEach ->
    nock.cleanAll()
    nock.disableNetConnect()

    @logger =
      log: () ->

    @discoveryServer = "http://discover-server"

    @serverList =
      getRandom: sinon.spy () =>
        Promise.resolve @discoveryServer

      dropServer: sinon.spy()

    @announcementIndex =
      processUpdate: sinon.spy()

    @discoveryNotifier =
      notifyError: sinon.spy()
      notifyWatchers: sinon.spy()

    @discoveryLongPoller = new DiscoveryLongPoller testServiceName, @serverList, @announcementIndex, @discoveryNotifier

  afterEach ->
    nock.cleanAll()

  describe "start polling", ->
    it "starts polling with a server", (done) ->
      @discoveryLongPoller.schedulePoll = done
      @discoveryLongPoller.startPolling()

    it "starting polling twice has no effect", ->
      @discoveryLongPoller.schedulePoll = sinon.spy()
      @discoveryLongPoller.startPolling()
      @discoveryLongPoller.startPolling()
      expect(@discoveryLongPoller.schedulePoll.callCount).to.equal 1

    it "reschedules a poll", (done) ->
      @announcementIndex.index = 1
      watch = nock(@discoveryServer)
        .get("/watch?since=2&clientServiceType=#{testServiceName}")
        .times(2)
        .reply(200)

      # we don't need to increment the since here because we never update
      # announcement index as we replace handleResponse
      sinon.spy(@discoveryLongPoller, 'schedulePoll')

      @discoveryLongPoller.handleResponse = () =>
        if watch.isDone()
          expect(@discoveryLongPoller.schedulePoll.callCount).to.equal 2
          @discoveryLongPoller.stopPolling()
          done()

      @discoveryLongPoller.startPolling()

  it "stop polls", (done) ->
    this.timeout(500)

    @announcementIndex.index = 1
    longPoll = nock(@discoveryServer)
      .get("/watch?since=2&clientServiceType=#{testServiceName}")
      .delay(200)
      .reply(204)

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

    it "calls process and watchers if 200", (done) ->
      @announcementIndex.index = 1
      nock(@discoveryServer)
        .get("/watch?since=2&clientServiceType=#{testServiceName}")
        .reply(200)

      @discoveryLongPoller.poll().then () =>
        expect(@announcementIndex.processUpdate.called).to.be.ok
        expect(@discoveryNotifier.notifyWatchers.called).to.be.ok
        done()
      .catch done

    it "calls nothing if 204", (done) ->
      @announcementIndex.index = 1
      nock(@discoveryServer)
        .get("/watch?since=2&clientServiceType=#{testServiceName}")
        .reply(204)

      @announcementIndex.processUpdate = () ->
        done new Error('should not be called')

      @discoveryLongPoller.poll().then () ->
        done()
      .catch done

    it "drops the server if bad", (done) ->
      @announcementIndex.index = 1
      nock(@discoveryServer)
        .get("/watch?since=2&clientServiceType=#{testServiceName}")
        .reply(500)

      @discoveryLongPoller.poll().then () =>
        expect(@serverList.dropServer.called).to.be.ok
        done()
      .catch done

    it "drops if it excepts", (done) ->
      @announcementIndex.index = 1
      nock(@discoveryServer)
        .get("/watch?since=2&clientServiceType=#{testServiceName}")
        .replyWithError('some socket error')

      @discoveryLongPoller.poll().then () =>
        expect(@serverList.dropServer.called).to.be.ok
        done()
      .catch done

    it "always uses the next index", (done) ->
      @announcementIndex.index = 100
      nock(@discoveryServer)
        .get("/watch?since=101&clientServiceType=#{testServiceName}")
        .reply(204)
      @discoveryLongPoller.handleResponse = () ->
        done()
      @discoveryLongPoller.poll()
