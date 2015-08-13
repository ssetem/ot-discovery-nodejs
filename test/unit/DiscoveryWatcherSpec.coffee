DiscoveryWatcher = require "#{srcDir}/DiscoveryWatcher"
nock = require "nock"
_ = require "lodash"
sinon = require "sinon"
Promise = require "bluebird"

describe "DiscoveryWatcher", ->

  beforeEach ->
    nock.cleanAll()
    nock.disableNetConnect()

    @discoveryServer = "discover-server"

    @discoveryWatcher = new DiscoveryWatcher

    @reply =
      good: true

  afterEach ->
    nock.cleanAll()

  it "watches with just a server", (done) ->
    watch =
      nock("http://" + @discoveryServer)
        .get('/watch')
        .reply(200, @reply)

    @discoveryWatcher.watch @discoveryServer
      .spread (statusCode, body) =>
        expect(statusCode).to.equal 200
        expect(body).to.deep.equal @reply
        watch.done()
        done()
      .catch done

  it "watches with servicename and index", (done) ->
    watch =
      nock("http://" + @discoveryServer)
        .get('/watch?since=100&clientServiceType=foo')
        .reply(200, @reply)

    @discoveryWatcher.watch @discoveryServer, 'foo', 100
      .spread (statusCode, body) =>
        expect(body).to.deep.equal @reply
        watch.done()
        done()
      .catch done

  it "rejects if there is an error", (done) ->
    watch =
      nock("http://" + @discoveryServer)
        .get('/watch')
        .replyWithError('badness')

    @discoveryWatcher.watch @discoveryServer
      .then () ->
        done "should not be called"
      .catch (e) ->
        watch.done()
        done()

  it "rejects if it is not 200 or 204", (done) ->
    watch =
      nock("http://" + @discoveryServer)
        .get('/watch')
        .reply(500)

    @discoveryWatcher.watch @discoveryServer
      .then () ->
        done "should not be called"
      .catch (e) ->
        watch.done()
        done()

   it "aborts", (done) ->
    this.timeout 250 # make sure we timeout before the delay
    watch =
      nock "http://" + @discoveryServer
        .get '/watch'
        .delay 500
        .reply 200, 'message'

    @discoveryWatcher.watch @discoveryServer
      .then () ->
        done 'should not complete'
      .catch done

    process.nextTick () =>
      @discoveryWatcher.abort()
      done()
