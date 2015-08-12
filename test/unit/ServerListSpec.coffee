ServerList = require("#{srcDir}/ServerList")
sinon = require "sinon"
Promises = require "bluebird"

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

  describe "getRandom", ->
    before () ->
      @servers = ["s1", "s2"]

    it "returns an promise that resolves when there are servers", (done) ->
      @connect = sinon.spy () ->
        done new Error("should not be called")

      @serverList.addServers @servers

      @serverList.getRandom()
        .then (server) =>
          expect(server in @servers).to.equal true
          done()
        .catch(done)

    it "calls connect to get more servers when there is not", (done) ->
      @serverList.connect = sinon.spy () =>
        Promises.resolve @servers

      @serverList.getRandom()
        .then (server) =>
          expect(server in @servers).to.equal true
          expect(@serverList.connect.called).to.be.ok
          done()
        .catch(done)

    it "will reject if connect fail", (done) ->
      @serverList.connect = sinon.spy () ->
        Promises.reject new Error("badness")

      @serverList.getRandom()
        .then (server) ->
          done new Error("Should not be called")
        .catch (err) ->
          done()

  it "dropServer()", ->
    @serverList.servers = ["s1", "s2"]
    @serverList.dropServer()
    expect(@serverList.servers).to.deep.equal ["s1", "s2"]
    @serverList.dropServer("s1")
    expect(@serverList.servers).to.deep.equal ["s2"]
