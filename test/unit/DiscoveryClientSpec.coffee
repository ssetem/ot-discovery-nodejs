DiscoveryClient = require "#{srcDir}/DiscoveryClient"
Promise = require "bluebird"
_ = require "lodash"

describe "DiscoveryClient", ->
  before ->
    @createDisco = (params) ->
      return new (Function.prototype.bind.apply(DiscoveryClient,[null].concat(params)))

    @expectThrow = (params, throwMessage) ->
      expect(() => 
        @createDisco(params)
      ).to.throw(throwMessage)

    @expectNotToThrow = (params) ->
      disco = null
      expect(() => 
        disco = @createDisco params 
      ).to.not.throw()
      disco
  
  describe "v1 api facading", ->
    it "supports just a host and options", ->
      options = {}
      client = @expectNotToThrow ['anything', options]
      expect(client.host).to.equal('anything')
      expect(client._announcementHosts).to.deep.equal(['anything'])
      expect(client.homeRegionName).to.not.be.ok
      expect(client.serviceName).to.not.be.ok
      expect(client.options).to.equal(options)

  it "uses logger if not passed", ->
    client = @expectNotToThrow 'anything'
    expect(client.logger).to.equal require("#{srcDir}/ConsoleLogger")

  it "uses options logger if passed", ->
    myLogger =
      log: () ->

    client = @expectNotToThrow ['anything', {logger: myLogger}]
    expect(client.logger).to.equal(myLogger)

  describe "v2 api", ->
    beforeEach ->
      @discoveryClient = Promise.promisifyAll @expectNotToThrow [
        api2testHosts.discoverRegionHost,
        api2testHosts.announceHosts,
        'homeregion',
        testServiceName, {
          logger:
            log: () ->
        }]

      @announcers = @discoveryClient._discoveryAnnouncers

    it "throws exceptions on bad constructor parameters", ->
      options =
        logger:
          log: ()->

      @expectNotToThrow ["hostname", options]
      @expectThrow ["hostname", "badannounce", null, null], 'announcementHosts must be an array of hostnames(strings).'
      @expectThrow ["hostname", ['host1'],{notAGoodParam:''},{notAGoodParam:''}, options], 'homeRegionName must be a valid string.'
      @expectThrow ["hostname", ['host1'],'myhostname',{notAGoodParam:''}, options], 'serviceName must be a valid string.'
      @expectNotToThrow ["hostname", ['host1'],'myhostname','myServiceName', options]
      @expectThrow [], 'Incorrect number of parameters: 0, DiscoveryClient expects 1(+1) or 4(+1)'
      @expectThrow [null,null,null], 'Incorrect number of parameters: 3, DiscoveryClient expects 1(+1) or 4(+1)'
      @expectThrow [null,null,null,null,null,null], 'Incorrect number of parameters: 6, DiscoveryClient expects 1(+1) or 4(+1)'


    it "throws exception with bad hostnames", ->
      @expectThrow ["http://hostname", ['host1'],'myhostname','myServiceName', {}],
        'host/announcementhost should not contain http:// - use direct host name'

      @expectThrow ["hostname", ['host1', 'http://badhostname'],'myhostname','myServiceName', {}],
        'host/announcementhost should not contain http:// - use direct host name'


    it "creates announcers in each region", ->
      expect(@announcers).to.have.length(2)

    it "connect connects, long polls, and heartbeats", (done) ->
      updates =
        fullUpdate: true
        index: 1
        updates: [{
          serviceType: 'discovery',
          serviceUri: 'a.disco'
        }]

      @discoveryClient.discoveryWatcher.watch = sinon.spy (server) ->
        expect(server).to.equal api2testHosts.discoverRegionHost
        Promise.resolve updates

      sinon.spy @discoveryClient.announcementIndex, 'processUpdate'
      @discoveryClient.schedulePoll = sinon.spy()
      @discoveryClient.startAnnouncementHeartbeat = sinon.spy()
      @discoveryClient.connect (err, host, servers) =>
        if err
          return done(err)

        expect(@discoveryClient.announcementIndex.processUpdate.calledWith(updates))
          .to.be.ok
        expect(@discoveryClient.polling).to.be.ok
        expect(@discoveryClient.schedulePoll.called)
          .to.be.ok
        expect(@discoveryClient.startAnnouncementHeartbeat.called)
          .to.be.ok
        expect(host).to.equal(api2testHosts.discoverRegionHost)
        expect(servers).to.deep.equal(['a.disco'])

        done()

    it "connect notifies and errors on failure", (done) ->
      @discoveryClient.discoveryWatcher.watch = sinon.spy () ->
        Promise.reject new Error('badness')

      @discoveryClient.connect (err) ->
        expect(err).to.be.ok
        done()

    it "reconnects connects and saves update (but does nothing else)", (done) ->
      updates =
        fullUpdate: true
        index: 1
        updates: [{
          serviceType: 'discovery',
          serviceUri: 'a.disco'
        }]

      @discoveryClient.discoveryWatcher.watch = sinon.spy () ->
        Promise.resolve updates

      sinon.spy @discoveryClient.announcementIndex, 'processUpdate'

      @discoveryClient.schedulePoll = sinon.spy()
      @discoveryClient.startAnnouncementHeartbeat = sinon.spy()
      @discoveryClient.reconnect()
        .then (servers) =>
          expect(@discoveryClient.announcementIndex.processUpdate.calledWith(updates))
            .to.be.ok
          expect(@discoveryClient.schedulePoll.called)
            .to.not.be.ok
          expect(@discoveryClient.startAnnouncementHeartbeat.called)
            .to.not.be.ok
          expect(servers).to.deep.equal ['a.disco']
          done()
        .catch(done)

    it "reconnect will try multiple times when connect rejects", (done) ->
      updates =
        fullUpdate: true
        index: 1
        updates: [{
          serviceType: 'discovery',
          serviceUri: 'a.disco'
        }]

      @discoveryClient.discoveryWatcher.watch = sinon.spy () =>
        call = @discoveryClient.discoveryWatcher.watch.callCount
        console.log call, 'call'
        if call == 1
          Promise.reject new Error('badness')
        else
          Promise.resolve updates

      sinon.spy @discoveryClient.announcementIndex, 'processUpdate'
      @discoveryClient.schedulePoll = sinon.spy()
      @discoveryClient.startAnnouncementHeartbeat = sinon.spy()

      @discoveryClient.reconnect()
        .then () =>
          expect(@discoveryClient.discoveryWatcher.watch.callCount).to.equal 2
          done()

    it "heartbeat start calls heartbeat on each region", ->
      _.each @announcers, (ann) ->
        ann.startAnnouncementHeartbeat = sinon.spy()
      @discoveryClient.startAnnouncementHeartbeat()
      _.each @announcers, (ann) ->
        expect(ann.startAnnouncementHeartbeat.called).to.be.ok

    it "heartbeat stop calls heartbeat on each region", ->
      _.each @announcers, (ann) ->
        ann.stopAnnouncementHeartbeat = sinon.spy()
      @discoveryClient.stopAnnouncementHeartbeat()
      _.each @announcers, (ann) ->
        expect(ann.stopAnnouncementHeartbeat.called).to.be.ok

    it "announce announces in each region", (done) ->
      _.each @announcers, (ann) ->
        ann.announce = sinon.spy (announce) ->
          Promise.resolve(announce)
      announcement = {}
      @discoveryClient.announce(announcement).then (result) =>
        expect(result).to.deep.equal([announcement, announcement])
        expect(@announcers[0].announce.calledWith(announcement)).to.be.ok
        expect(@announcers[1].announce.calledWith(announcement)).to.be.ok
        expect(@announcers[0].announce.calledOn(@announcers[0])).to.be.ok
        expect(@announcers[1].announce.calledOn(@announcers[1])).to.be.ok
        done()
      .catch(done)

    it "announce fails if one announce fails and error watchers", (done) ->
      @announcers[0].announce = sinon.spy (announce) ->
        Promise.resolve(announce)
      @announcers[1].announce = sinon.spy (announce) ->
        Promise.reject new Error('an error')

      errorSpy = sinon.spy()
      @discoveryClient.onError errorSpy

      @discoveryClient.announce({}).then (result) ->
        done new Error('should not get here')
      .catch (err) ->
        expect(errorSpy.called).to.be.ok
        expect(err).to.be.ok
        done()

    it "unannounce unannounces in each region", (done) ->
      _.each @announcers, (ann) ->
        ann.unannounce = sinon.spy (a) ->
          Promise.resolve()

      @discoveryClient.unannounce([1,2]).then () =>
        expect(@announcers[0].unannounce.calledWith(1)).to.be.ok
        expect(@announcers[1].unannounce.calledWith(2)).to.be.ok
        expect(@announcers[0].unannounce.calledOn(@announcers[0])).to.be.ok
        expect(@announcers[1].unannounce.calledOn(@announcers[1])).to.be.ok
        done()
      .catch(done)

    it "unannounce fails if one unannounce fails and error watchers", (done) ->
      @announcers[0].unannounce = sinon.spy()
      @announcers[1].unannounce = sinon.spy () ->
        Promise.reject new Error('something')

      errorSpy = sinon.spy()
      @discoveryClient.onError errorSpy

      @discoveryClient.unannounce([1,2]).then () ->
        done new Error('should not get here')
      .catch (err) ->
        expect(errorSpy.called).to.be.ok
        expect(err).to.be.ok
        done()

    it "disconnet stops everything", ->
      @discoveryClient.stopAnnouncementHeartbeat = sinon.spy()
      @discoveryClient.discoveryWatcher.abort = sinon.spy()
      @discoveryClient.disconnect()
      expect(@discoveryClient.stopAnnouncementHeartbeat.called).to.be.ok
      expect(@discoveryClient.discoveryWatcher.abort.called).to.be.ok

    it "find calls announcementIndex", ->
      @discoveryClient.announcementIndex.find = sinon.spy()
      @discoveryClient.find("discovery")
      expect(@discoveryClient.announcementIndex.find.called).to.be.ok

    it "findAll calls announcementIndex", ->
      @discoveryClient.announcementIndex.findAll = sinon.spy()
      @discoveryClient.findAll("discovery")
      expect(@discoveryClient.announcementIndex.findAll.called).to.be.ok

    it "make sure discovery can be promisified", ->
      expect(@discoveryClient).to.respondTo 'connectAsync'
      expect(@discoveryClient).to.respondTo 'announceAsync'
      expect(@discoveryClient).to.respondTo 'unannounceAsync'
