DiscoveryClient = require "#{srcDir}/DiscoveryClient"
Promise = require "bluebird"
_ = require "lodash"
sinon = require "sinon"

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
      expect(client.serviceType).to.not.be.ok
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
      @discoveryClient = Promise.promisifyAll new DiscoveryClient(
        api2testHosts.discoverRegionHost,
        api2testHosts.announceHosts,
        'homeregion',
        'testService', {
          logger:
            log: () ->
        })

      @announcers = @discoveryClient._discoveryAnnouncers

    it "throws exceptions on bad constructor parameters", ->
      options =
        logger:
          log: ()->

      @expectNotToThrow ["hostname", options]
      @expectThrow ["hostname", "badannounce", null, null], 'announcementHosts must be an array of hostnames(strings).'
      @expectThrow ["hostname", ['host1'],{notAGoodParam:''},{notAGoodParam:''}, options], 'homeRegionName must be a valid string.'
      @expectThrow ["hostname", ['host1'],'myhostname',{notAGoodParam:''}, options], 'serviceType must be a valid string.'
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

    it "connect connects, long polls", (done) ->
      updates =
        fullUpdate: true
        index: 1
        updates: [{
          serviceType: 'discovery',
          serviceUri: 'a.disco'
        }]

      @discoveryClient.discoveryWatcher.watch = sinon.spy (server) ->
        expect(server).to.equal api2testHosts.discoverRegionHost
        Promise.resolve [200, updates]

      sinon.spy @discoveryClient.announcementIndex, 'processUpdate'
      replaceMethod @discoveryClient, 'schedulePoll'

      @discoveryClient.connect (err, host, servers) =>
        if err
          return done(err)
        #long poll starts after a process.nextTick... act accordinglys
        process.nextTick () =>
          expect(@discoveryClient.announcementIndex.processUpdate.calledWith(updates))
            .to.be.ok
          expect(@discoveryClient.polling).to.be.ok
          expect(@discoveryClient.schedulePoll.called)
            .to.be.ok
          expect(host).to.equal(api2testHosts.discoverRegionHost)
          expect(servers).to.deep.equal(['a.disco'])

          done()

    it "connect notifies and errors on failure", (done) ->
      replaceMethod @discoveryClient.discoveryWatcher, 'watch', sinon.spy () ->
        Promise.reject new Error('badness')

      @discoveryClient.connect (err) ->
        expect(err).to.be.ok
        done()

    it "connect notifies on bad code", (done) ->
      replaceMethod @discoveryClient.discoveryWatcher, 'watch', sinon.spy () ->
        Promise.resolve [204, {}]

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

      replaceMethod @discoveryClient.discoveryWatcher, 'watch', sinon.spy () ->
        Promise.resolve [200, updates]

      sinon.spy @discoveryClient.announcementIndex, 'processUpdate'

      replaceMethod @discoveryClient, 'schedulePoll'

      @discoveryClient.reconnect()
        .then (servers) =>
          expect(@discoveryClient.announcementIndex.processUpdate.calledWith(updates))
            .to.be.ok
          expect(@discoveryClient.schedulePoll.called)
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

      replaceMethod @discoveryClient.discoveryWatcher, 'watch', sinon.spy () =>
        call = @discoveryClient.discoveryWatcher.watch.callCount
        if call == 1
          Promise.reject new Error('badness')
        else
          Promise.resolve [200, updates]

      sinon.spy @discoveryClient.announcementIndex, 'processUpdate'
      replaceMethod @discoveryClient, 'schedulePoll'

      @discoveryClient.reconnect()
        .then () =>
          expect(@discoveryClient.discoveryWatcher.watch.callCount).to.equal 2
          done()

    it "announce sets the homeRegion if given", (done) ->
      _.each @announcers, (ann) ->
        replaceMethod ann, 'announce', sinon.spy (announce) ->
          Promise.resolve announce
      announcement = {}
      @discoveryClient.announce(announcement).then (result) ->
        expect(result[0]).to.have.property('environment').to.equal 'homeregion'
        done()
      .catch done

    it "announce does not set the homeRegion if not given", (done) ->
      _.each @announcers, (ann) ->
        replaceMethod ann, 'announce', sinon.spy (announce) ->
          Promise.resolve announce

      announcement = {}
      @discoveryClient._homeRegionName = null

      @discoveryClient.announce(announcement).then (result) ->
        expect(result[0]).to.not.have.property 'environment'
        done()
      .catch done

    it "announce announces in each region", (done) ->
      _.each @announcers, (ann) ->
        replaceMethod ann, 'announce', sinon.spy (announce) ->
          Promise.resolve(announce)

      announcement =
        serviceType: 'service'
        serviceUri: 'foobar.com'

      @discoveryClient.announce(announcement).then (lease) =>
        expect(announcement).to.deep.equal {
          serviceType: 'service'
          serviceUri: 'foobar.com'
        }

        expect(lease).to.be.ok

        _.each @announcers, (ann) ->
          expect(ann.announce.firstCall.args[0].serviceType).to.equal 'service'
          expect(ann.announce.firstCall.args[0].serviceUri).to.equal 'foobar.com'
          expect(ann.announce.firstCall.args[0]).to.not.have.property 'announcementId'

        done()
      .catch(done)

    it "announce fails if one announce fails and error watchers", (done) ->
      replaceMethod @announcers[0], 'announce', sinon.spy (announce) ->
        Promise.resolve(announce)
      replaceMethod @announcers[1], 'announce', sinon.spy (announce) ->
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
        replaceMethod ann, 'unannounce', sinon.spy (a) ->
          Promise.resolve()

      @discoveryClient.unannounce([1,2]).then () =>
        expect(@announcers[0].unannounce.calledWith(1)).to.be.ok
        expect(@announcers[1].unannounce.calledWith(2)).to.be.ok
        expect(@announcers[0].unannounce.calledOn(@announcers[0])).to.be.ok
        expect(@announcers[1].unannounce.calledOn(@announcers[1])).to.be.ok
        done()
      .catch(done)

    it "unannounce fails if one unannounce fails and error watchers", (done) ->
      replaceMethod @announcers[0], 'unannounce'
      replaceMethod @announcers[1], 'unannounce', sinon.spy () ->
        Promise.reject new Error('something')

      errorSpy = sinon.spy()
      @discoveryClient.onError errorSpy

      @discoveryClient.unannounce([1,2]).then () ->
        done new Error('should not get here')
      .catch (err) ->
        expect(errorSpy.called).to.be.ok
        expect(err).to.be.ok
        done()

    it "disconnect stops everything", ->
      replaceMethod @discoveryClient.discoveryWatcher, 'abort'
      _.each @announcers, (ann) ->
        replaceMethod ann, 'stopHeartbeat'
      @discoveryClient.disconnect()
      expect(@discoveryClient.discoveryWatcher.abort.called, 'abort called').to.be.ok
      _.each @announcers, (ann) ->
        expect(ann.stopHeartbeat.called, 'stop heartbeat called').to.be.ok

    it "find calls announcementIndex", ->
      replaceMethod @discoveryClient.announcementIndex, 'find'
      @discoveryClient.find("discovery")
      expect(@discoveryClient.announcementIndex.find.called).to.be.ok

    it "findAll calls announcementIndex", ->
      replaceMethod @discoveryClient.announcementIndex, 'findAll'
      @discoveryClient.findAll("discovery")
      expect(@discoveryClient.announcementIndex.findAll.called).to.be.ok

    it "make sure discovery can be promisified", ->
      expect(@discoveryClient).to.respondTo 'connectAsync'
      expect(@discoveryClient).to.respondTo 'announceAsync'
      expect(@discoveryClient).to.respondTo 'unannounceAsync'

  describe "polling", ->
    beforeEach () ->
      @discoveryClient = new DiscoveryClient 'ahost'
      @update =
        fullUpdate: true
        index: 1
        updates: [{
          serviceType: 'discovery',
          serviceUri: 'a.disco'
        }]

    it "calls save update and notify when success", (done) ->
      @discoveryClient.serverList.addServers ['a.com']
      @discoveryClient.announcementIndex.index = 100

      replaceMethod @discoveryClient.discoveryWatcher, 'watch', sinon.spy (server) =>
        Promise.resolve [200, @update]

      notifyWatch = sinon.spy()
      @discoveryClient.onUpdate notifyWatch

      sinon.spy @discoveryClient.announcementIndex, 'processUpdate'

      @discoveryClient.poll().then () =>
        expect(@discoveryClient.discoveryWatcher.watch.called).to.be.ok
        expect(@discoveryClient.announcementIndex.processUpdate.called).to.be.ok
        expect(notifyWatch.called).to.be.ok
        done()
      .catch done

    it "increments the index on every poll", (done) ->
      @discoveryClient.serverList.addServers ['a.com']
      @discoveryClient.announcementIndex.index = 100

      replaceMethod @discoveryClient.discoveryWatcher, 'watch', sinon.spy (server, seviceName, index) ->
        expect(index).to.equal 101
        Promise.resolve [204, {}]

      @discoveryClient.poll().then () =>
        expect(@discoveryClient.discoveryWatcher.watch.called).to.be.ok
        done()
      .catch done

    it "drops a bad server and notify errors", (done) ->
      @discoveryClient.serverList.addServers ['a.com']

      replaceMethod @discoveryClient.discoveryWatcher, 'watch', sinon.spy (server) ->
        Promise.reject 'bad server'

      notifyError = sinon.spy()

      @discoveryClient.onError notifyError

      @discoveryClient.poll().then () ->
        done 'should not get here'
      .catch (e) =>
        expect(@discoveryClient.serverList.isEmpty()).to.be.ok
        expect(notifyError.called).to.be.ok
        done()

    it "calls reconnect when all servers are gone", (done) ->
      replaceMethod @discoveryClient.discoveryWatcher, 'watch', sinon.spy (server) =>
        if server == 'ahost'
          #reconnect!
          Promise.resolve [200, @update]
        else if server == 'a.disco'
          #rewatch!
          Promise.resolve [204, {}]
        else
          expect(false, "bad server! " + server).to.be.ok

      @discoveryClient.poll().then () =>
        expect(@discoveryClient.discoveryWatcher.watch.called, 'watch called').to.be.ok
        done()
      .catch done

    it "does nothing unless @polling", ->
      replaceMethod @discoveryClient.serverList, 'getRandom', sinon.spy()
      @discoveryClient.schedulePoll()
      expect(@discoveryClient.serverList.getRandom.called).to.be.not.ok

    it "calls poll when polling", (done) ->
      @discoveryClient.polling = true
      replaceMethod @discoveryClient, 'poll', sinon.spy () =>
        @discoveryClient.polling = false
        done()
        Promise.resolve()
      @discoveryClient.schedulePoll()
