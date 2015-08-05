ServerList = require("#{srcDir}/ServerList")
sinon = require "sinon"

describe "ServerList", ->
  beforeEach ->
    @logger =
      log: sinon.spy()

    @serverList = new ServerList @logger

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
