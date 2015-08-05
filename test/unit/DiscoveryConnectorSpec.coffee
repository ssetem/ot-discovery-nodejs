DiscoveryClient = require("#{srcDir}/DiscoveryClient")
Utils = require("#{srcDir}/Utils")
nock = require "nock"
_ = require "lodash"

describe "DiscoveryConnector", ->

  beforeEach ->
    nock.cleanAll()
    nock.disableNetConnect()
    @discoveryClient = new DiscoveryClient( testHosts.discoverRegionHost, testHosts.announceHosts,testHomeRegionName, testServiceName, {
      logger:
        logs:[]
        log:()->
          # console.log arguments
          @logs.push(arguments)
    })
    @logger = @discoveryClient.logger
    @connector = @discoveryClient.discoveryConnector
    sinon.spy(Utils, "promiseRetry")
    @getRetryCalls = =>
      _.pluck(Utils.promiseRetry.getCalls(), "args")

    @discoveryServer = "http://" + @discoveryClient.host

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
    nock.cleanAll();
    Utils.promiseRetry.restore()

  it "should exist", ->
    expect(@connector).to.exist



  describe "connect", ->

    it "failure after 3 attempts", (done)->
      @connector.CONNECT_ATTEMPTS = 3
      @connector.INITIAL_BACKOFF = 1

      @connector.connect()
        .catch (e)=>
          expect(e.message).to.equal(
            'Nock: Not allow net connect for "' + @discoveryClient.host + ':80/watch' + "?clientServiceType=#{testServiceName}\"")
          expect([
            [@connector.attemptConnect, 3, 1]
            [@connector.attemptConnect, 2, 2]
            [@connector.attemptConnect, 1, 4]
            [@connector.attemptConnect, 0, 8]
          ]).to.deep.equal @getRetryCalls()
          done()

    it "success after 4 attempts", (done)->
      @connector.CONNECT_ATTEMPTS = 10
      @connector.INITIAL_BACKOFF = 1
      failedRequests =
        nock(@discoveryServer)
          .get("/watch?clientServiceType=#{testServiceName}")
          .times(2)
          .reply(500, "Simulated server error")
      nonFullUpdateRequests =
        nock(@discoveryServer)
          .get("/watch?clientServiceType=#{testServiceName}")
          .times(2)
          .reply(500, {fullUpdate:false})
      successfulRequest =
        nock(@discoveryServer)
          .get("/watch?clientServiceType=#{testServiceName}")
          .reply(200, @successfulUpdate)

      @errors = []
      @discoveryClient.onError (err)=>
        @errors.push(err)
        
      @connector.connect().then (result) =>
        failedRequests.done()
        nonFullUpdateRequests.done()
        successfulRequest.done()
        expect(result).to.deep.equal @successfulUpdate
        expect(_.pluck(@errors, "message")).to.deep.equal [
          'Unabled to initiate discovery: "Simulated server error"',
          'Unabled to initiate discovery: "Simulated server error"',
          'Unabled to initiate discovery: {"fullUpdate":false}',
          'Unabled to initiate discovery: {"fullUpdate":false}'
        ]
        done()
