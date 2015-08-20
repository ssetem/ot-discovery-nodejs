DiscoveryClient = require "#{srcDir}/DiscoveryClient"
DiscoveryIntegrationTestServer = require './DiscoveryIntegrationTestServer'
Promise = require 'bluebird'
sinon = require 'sinon'


describe "mock intergration server tests", ->
  beforeEach (done) =>
    @server1 = Promise.promisifyAll new DiscoveryIntegrationTestServer()
    @server2 = Promise.promisifyAll new DiscoveryIntegrationTestServer()
    Promise.join @server1.startAsync(9000), @server2.startAsync(9001), done


  afterEach (done) =>
    Promise.join @server1.endAsync(), @server2.endAsync(), done

  # basic test to make sure the client can connect and pull down the disco services
  connectFullUpdateTest = (client, done) ->
    client.onError (err) ->
      done err

    client.connect (err) ->
      if err then return done(err)
      expect(client.find 'discovery' ).to.be.ok
      expect(client.find 'NOTASERVICE' ).to.not.be.ok
      client.disconnect()
      done()

  respondToAnnounceTest = (client, done) ->
    client.onError (err) ->
      done err

    client.connect (err) ->
      if err then return done(err)
      client.announce
        serviceType: "node-discovery-demo",
        serviceUri: "fake://test"
      , (err, resp, something) ->
        if err then done(err)
        expect(resp).to.be.ok
        setTimeout () ->
          client.disconnect()
          expect(client.find 'node-discovery-demo').to.be.ok
          done()
        , 500

  respondToUnannounceTest = (client, done) ->
    client.onError (err) ->
      done err

    client.connect (err) ->
      client.announce
        serviceType: "node-discovery-demo",
        serviceUri: "fake://test"
      , (err, resp) ->
        client.unannounce resp, (err) ->
          if err then done(err)
          setTimeout () ->
            client.disconnect()
            expect(client.find 'node-discovery-demo').to.not.be.ok
            done()
          , 500

  describe "api v1 tests", ->
    it "should connect and do a full update", (done) ->
      connectFullUpdateTest( new DiscoveryClient('localhost:9000')
        , done)
      
    it "should announce", (done) ->
      respondToAnnounceTest( new DiscoveryClient('localhost:9000')
        , done)

    it "should unannounce", (done) ->
      respondToUnannounceTest( new DiscoveryClient('localhost:9000')
        , done)

  describe "api v2 tests", ->
    it "should connect and do a full update", (done) ->
      connectFullUpdateTest( new DiscoveryClient('localhost:9000', ['localhost:9001'], 'homeRegionName', 'test-serviceType')
        , done)
      
    it "should announce", (done) ->
      respondToAnnounceTest( new DiscoveryClient('localhost:9000', ['localhost:9001'], 'homeRegionName', 'test-serviceType')
        , done)

    it "should unannounce", (done) ->
      respondToUnannounceTest( new DiscoveryClient('localhost:9000', ['localhost:9001'], 'homeRegionName', 'test-serviceType')
        , done)

    it "should multi announce and then find service", (done) ->
      client = new DiscoveryClient 'localhost:9000', ['localhost:9000', 'localhost:9001'], 'homeRegionName', 'test-serviceType'
      
      client.onError (err) ->
        done err

      client.connect (err) ->
        if err then return done(err)
        client.announce
          serviceType: "test-serviceType",
          serviceUri: "fake://test"
        , (err, resp, something) ->
          if err then done(err)
          expect(resp).to.have.length(2)
          setTimeout () ->
            expect(client.findAll 'test-serviceType').to.be.ok
            expect(client.findAll 'test-serviceType').to.have.length 2
            client.disconnect()
            done()
          , 500

  xit "should do call GET /watch multiple times on discovery endpoint after connect update", (done) ->
  xit "should be able to get two seperate fullupdates from different disco servers", () ->
    