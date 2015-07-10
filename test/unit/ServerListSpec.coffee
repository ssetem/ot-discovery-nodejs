ServerList = require("#{srcDir}/ServerList")
DiscoveryClient = require("#{srcDir}/DiscoveryClient")


describe "ServerList", ->

  beforeEach ->
    @discoveryClient = new DiscoveryClient("host", {
      logger:
        logs:[]
        log:()->
          @logs.push(arguments)
    })
    @serverList = @discoveryClient.serverList

  it "should exist", ->
    expect(@serverList).toExist

  it "addServers()", ->
    @serverList.addServers(["s1", "s2"])
    @serverList.addServers(["s3", "s2"])

    expect(@serverList.servers).to.deep.equal [
      "s1", "s2", "s3"
    ]

  it "isEmpty()", ->
    expect(@serverList.isEmpty()).to.equal true
    @serverList.servers = ["s1"]
    expect(@serverList.isEmpty()).to.equal false

  it "getRandom()", ->
    @serverList.servers = ["s1", "s2", "s3"]

    expect(@serverList.getRandom() in @serverList.servers)
      .to.equal true

  it "dropServer()", ->
    @serverList.servers = ["s1", "s2"]
    @serverList.dropServer()
    expect(@serverList.servers).to.deep.equal ["s1", "s2"]
    @serverList.dropServer("s1")
    expect(@serverList.servers).to.deep.equal ["s2"]
