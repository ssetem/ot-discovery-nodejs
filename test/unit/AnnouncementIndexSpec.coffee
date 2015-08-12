AnnouncementIndex = require "#{srcDir}/AnnouncementIndex"
sinon = require "sinon"

describe "AnnouncementIndex", ->
  beforeEach ->
    @serverList =
      addServers: sinon.spy()

    @announcementIndex = new AnnouncementIndex @serverList
    
    @sampleAnnouncements = [
      {
        "announcementId":"a1",
        "serviceType":"discovery",
        "serviceUri":"http://1.1.1.1:2"
        "feature":"test"
      },
      {
        "announcementId":"a2",
        "serviceType":"myservice",
        "serviceUri":"http://1.1.1.1:2"
      }
    ]

    @announcementIndex.addAnnouncements @sampleAnnouncements

  it "addAnnouncements", ->
    expect(@announcementIndex.getAnnouncements()["a1"])
      .to.deep.equal @sampleAnnouncements[0]

    expect(@announcementIndex.getAnnouncements()["a2"])
      .to.deep.equal @sampleAnnouncements[1]

    @announcementIndex.addAnnouncements [{
      "announcementId":"a1"
      "serviceType":"discovery"
    }]

    expect(@announcementIndex.getAnnouncements()["a1"]).to.deep.equal {
      "announcementId":"a1"
      "serviceType":"discovery"
    }

  it "removeAnnouncements", ->
    @announcementIndex.removeAnnouncements(["a2"])
    expect(@announcementIndex.getAnnouncements()).to.deep.equal {
      "a1":@sampleAnnouncements[0]
    }

  it "clearAnnouncements()", ->
    @announcementIndex.clearAnnouncements()
    expect(@announcementIndex.getAnnouncements()).to.deep.equal {}

  it "computeDiscoverServers()", ->
    @announcementIndex.computeDiscoveryServers()
    expect(@announcementIndex.getDiscoveryServers())
      .to.deep.equal [@sampleAnnouncements[1].serviceUri]
    expect(@serverList.addServers.calledWithMatch([@sampleAnnouncements[1].serviceUri]))
      .to.be.ok

  it "processUpdate - fullUpdate", ->
    @announcementIndex.processUpdate
      fullUpdate:true
      index:1
      deletes:[]
      updates:[
        {announcementId:"b1", serviceType:"gc-web", serviceUri:"gcweb.otenv.com"}
        {announcementId:"b2", serviceType:"discovery", serviceUri:"discovery.otenv.com"}
      ]

    expect(@announcementIndex.getAnnouncements()).to.deep.equal {
      b1:
        announcementId: 'b1',
        serviceType: 'gc-web',
        serviceUri: 'gcweb.otenv.com'
      b2:
        announcementId: 'b2',
        serviceType: 'discovery',
        serviceUri: 'discovery.otenv.com'
    }
    expect(@announcementIndex.index).to.equal 1
    expect(@announcementIndex.discoveryServers).to.deep.equal [
      "discovery.otenv.com"
    ]

  it "fullUpdate with removal of old items on new watch=x update, and fullUpdate:false", ->
    @announcementIndex.processUpdate
      fullUpdate:true
      index:1
      deletes:[]
      updates:[
        {announcementId:"b1", serviceType:"gc-web", serviceUri:"gcweb.otenv.com"}
        {announcementId:"b2", serviceType:"discovery", serviceUri:"discovery.otenv.com"}
      ]

    @announcementIndex.processUpdate
      fullUpdate:false
      index:2
      deletes:["b1"]
      updates:[]

    expect(@announcementIndex.getAnnouncements()).to.deep.equal {
      b2:
        announcementId: 'b2',
        serviceType: 'discovery',
        serviceUri: 'discovery.otenv.com'
    }
    expect(@announcementIndex.index).to.equal 2
    expect(@announcementIndex.discoveryServers).to.deep.equal [
      "discovery.otenv.com"
    ]

  it "findAll()", ->
    expect(@announcementIndex.findAll()).to.deep.equal []
    expect(@announcementIndex.findAll("discovery")).to.deep.equal [
      @sampleAnnouncements[0].serviceUri
    ]
    expect(@announcementIndex.findAll("discovery:none"))
      .to.deep.equal []
    expect(@announcementIndex.findAll("discovery:test")).to.deep.equal [
      @sampleAnnouncements[0].serviceUri
    ]
    predicate = (announcement)->
      announcement.serviceType is "myservice"
    expect(@announcementIndex.findAll(predicate)).to.deep.equal [
      @sampleAnnouncements[1].serviceUri
    ]

  it "find()", ->
    expect(@announcementIndex.find()).to.equal undefined
    expect(@announcementIndex.find("discovery"))
      .to.deep.equal @sampleAnnouncements[0].serviceUri
    @announcementIndex.addAnnouncements [
      { "announcementId":"d1", "serviceType":"discovery", serviceUri:"uri" }
      { "announcementId":"d2", "serviceType":"discovery", serviceUri:"uri" }
      { "announcementId":"d3", "serviceType":"discovery", serviceUri:"uri"}
    ]

    expect(@announcementIndex.find("discovery")).to.exist

describe "AnnouncementIndex multi region", ->
  describe "find api", ->
    beforeEach ->
      @serverList =
        addServers: sinon.spy()
      @announcementIndex = new AnnouncementIndex @serverList
      
      @sampleAnnouncements = [
        {
          "announcementId":"a1",
          "serviceType":"discovery",
          "serviceUri":"http://1.1.1.1:2"
          "feature":"test",
          "environment": api2testHosts.announceHosts[0]
        },
        {
          "announcementId":"a2",
          "serviceType":"myservice",
          "serviceUri":"http://1.1.1.1:3"
          "environment": api2testHosts.announceHosts[0]
        },
        {
          "announcementId":"a2b",
          "serviceType":"myservice",
          "serviceUri":"http://99.99.99.99:3"
          "environment": api2testHosts.announceHosts[1]
        },
        {
          "announcementId":"a3",
          "serviceType":"nonlocalservice",
          "serviceUri":"http://99.99.99.99:4"
          "environment": api2testHosts.announceHosts[1]
        },
        {
          "announcementId":"a4a",
          "serviceType":"tonsofservers",
          "serviceUri":"http://1.1.1.1:1"
          "environment": api2testHosts.announceHosts[0]
        },
        {
          "announcementId":"a4b",
          "serviceType":"tonsofservers",
          "serviceUri":"http://1.1.1.1:2"
          "environment": api2testHosts.announceHosts[0]
        },
        {
          "announcementId":"a4c",
          "serviceType":"tonsofservers",
          "serviceUri":"http://1.1.1.1:3"
          "environment": api2testHosts.announceHosts[0]
        },
        {
          "announcementId":"a4d",
          "serviceType":"tonsofservers",
          "serviceUri":"http://1.1.1.9:3"
          "environment": api2testHosts.announceHosts[1]
        }
      ]

      @announcementIndex.addAnnouncements @sampleAnnouncements

    it "findAll() should return local environment services given two regions", ->
      predicate = (announcement)->
        announcement.serviceType is "myservice"

      expect(@announcementIndex.findAll(predicate, api2testHosts.announceHosts[0]))
        .to.deep.equal [
          @sampleAnnouncements[1].serviceUri
        ]
      
    it "should return non-local environment given only non-local environment", ->
      predicate = (announcement)->
        announcement.serviceType is "nonlocalservice"

      expect(@announcementIndex.findAll(predicate)).to.deep.equal [
        @sampleAnnouncements[3].serviceUri
      ]

    it "should return all the local services given predicate", ->
      predicate = (announcement)->
        announcement.serviceType is "tonsofservers"

      expect(@announcementIndex.findAll(predicate)).to.deep.equal [
        @sampleAnnouncements[4].serviceUri,
        @sampleAnnouncements[5].serviceUri,
        @sampleAnnouncements[6].serviceUri,
        @sampleAnnouncements[7].serviceUri
      ]


