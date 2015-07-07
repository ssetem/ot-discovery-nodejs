AnnouncementIndex = require("#{srcDir}/AnnouncementIndex")


describe "AnnouncementIndex", ->

  beforeEach ->
    @announcementIndex = new AnnouncementIndex()

    @sampleAnnouncements = [
      {
        "announcementId":"a1",
        "staticAnnouncement":false,
        "announceTime":"2015-03-30T18:26:52.178Z",
        "serviceType":"discovery",
        "serviceUri":"http://1.1.1.1:2"
        "feature":"test"
      },
      {
        "announcementId":"a2",
        "staticAnnouncement":false,
        "announceTime":"2015-03-30T18:26:52.178Z",
        "serviceType":"myservice",
        "serviceUri":"http://1.1.1.1:2"
      }
    ]

    @announcementIndex.addAnnouncements @sampleAnnouncements


  it "should exist", ->
    expect(@announcementIndex).to.exist


  it "addAnnouncements", ->

    expect(@announcementIndex.announcements["a1"])
      .to.deep.equal @sampleAnnouncements[0]

    expect(@announcementIndex.announcements["a2"])
      .to.deep.equal @sampleAnnouncements[1]

    @announcementIndex.addAnnouncements [{
      "announcementId":"a1"
      "serviceType":"discovery"
    }]

    expect(@announcementIndex.announcements["a1"]).to.deep.equal {
      "announcementId":"a1"
      "serviceType":"discovery"
    }

  it "removeAnnouncements", ->
    @announcementIndex.removeAnnouncements(["a2"])
    expect(@announcementIndex.announcements).to.deep.equal {
      "a1":@sampleAnnouncements[0]
    }

  it "clearAnnouncements()", ->
    @announcementIndex.clearAnnouncements()
    expect(@announcementIndex.announcements).to.deep.equal {}

  it "computeDiscoverServers()", ->
    @announcementIndex.computeDiscoveryServers()
    expect(@announcementIndex.getDiscoveryServers())
      .to.deep.equal [@sampleAnnouncements[1].serviceUri]


  it "processUpdate - fullUpdate", ->
    @announcementIndex.processUpdate({
      fullUpdate:true
      index:1
      deletes:[]
      updates:[
        {announcementId:"b1", serviceType:"gc-web", serviceUri:"gcweb.otenv.com"}
        {announcementId:"b2", serviceType:"discovery", serviceUri:"discovery.otenv.com"}
      ]
    })
    expect(@announcementIndex.announcements).to.deep.equal {
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

  it "findAll()", ->
    expect(@announcementIndex.findAll()).to.deep.equal []
    expect(@announcementIndex.findAll("discovery")).to.deep.equal [
      @sampleAnnouncements[0]
    ]
    expect(@announcementIndex.findAll("discovery:none"))
      .to.deep.equal []
    expect(@announcementIndex.findAll("discovery:test")).to.deep.equal [
      @sampleAnnouncements[0]
    ]
    predicate = (announcement)->
      announcement.serviceType is "myservice"
    expect(@announcementIndex.findAll(predicate)).to.deep.equal [
      @sampleAnnouncements[1]
    ]

  it "find()", ->
    expect(@announcementIndex.find()).to.equal undefined
    expect(@announcementIndex.find("discovery"))
      .to.deep.equal @sampleAnnouncements[0]

    @announcementIndex.addAnnouncements [
      { "announcementId":"d1", "serviceType":"discovery" }
      { "announcementId":"d2", "serviceType":"discovery" }
      { "announcementId":"d3", "serviceType":"discovery" }
    ]

    expect(@announcementIndex.find("discovery").announcementId in ["a1", "d1", "d2", "d3"])
      .to.equal true



