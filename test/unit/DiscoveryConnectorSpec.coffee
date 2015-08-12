DiscoveryConnector = require("#{srcDir}/DiscoveryConnector")
Utils = require("#{srcDir}/Utils")
nock = require "nock"
_ = require "lodash"
sinon = require "sinon"
Promise = require "bluebird"

describe "DiscoveryConnector", ->

  beforeEach ->
    nock.cleanAll()
    nock.disableNetConnect()
    @host = "ahost.com"
    @logger =
      log: sinon.spy()

    @connector = new DiscoveryConnector @host, null, @logger

    @discoveryServer = "http://" + @host

    @successfulUpdate = {
      "fullUpdate":true,
      "index":100,
      "deletes":[],
      "updates":[
          {
            "announcementId":"discovery",
            "staticAnnouncement":false,
            "announceTime":"2015-03-30T18:26:52.178Z",
            "serviceType":"discovery",
            "serviceUri":"http://2.2.2.2:3"
          },
          {
            "announcementId":"old",
            "staticAnnouncement":false,
            "announceTime":"2015-03-30T18:26:52.178Z",
            "serviceType":"my-service",
            "serviceUri":"http://1.1.1.1:2"
          }
        ]
      }

  afterEach ->
    nock.cleanAll()

  describe "connect", ->
    it "fails from catch", (done) ->
      @connector.connect()
        .catch (e) =>
          expect(e.message).to.equal(
            'Nock: Not allow net connect for "' + @host + ':80/watch"')
          done()

    it "fails from non-good status code", (done) ->
      failedRequests =
        nock(@discoveryServer)
          .get("/watch")
          .reply(500, "Simulated server error")
      @connector.connect()
        .catch (e) ->
          expect(e).to.be.ok
          done()

    it "fails from a non-full update", (done) ->
      nonFullUpdateRequests =
        nock(@discoveryServer)
          .get("/watch")
          .reply(500, {fullUpdate:false})
      @connector.connect()
        .catch (e) ->
          expect(e).to.be.ok
          done()


    it "success", (done) ->
      successfulRequest =
        nock(@discoveryServer)
          .get("/watch")
          .reply(200, @successfulUpdate)

      @connector.connect().then (result) =>
        successfulRequest.done()
        expect(result).to.deep.equal @successfulUpdate
        done()

    describe 'api v2', () ->
      it 'should use watch?clientServiceType=x interface', () ->
        connector = new DiscoveryConnector @host, testServiceName, @logger, @discoveryNotifier
        successfulRequest = nock(@discoveryServer)
          .get("/watch?clientServiceType=#{testServiceName}")
          .reply(200, @successfulUpdate)

        connector.connect().then (result) =>
          successfulRequest.done()
          expect(result).to.deep.equal @successfulUpdate
