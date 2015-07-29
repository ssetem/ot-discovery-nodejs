DiscoveryClient = require("#{srcDir}/DiscoveryClient")


describe "AnnouncementIndex", ->

  beforeEach ->
    @discoveryClient = new DiscoveryClient( testHosts.discoverRegionHost, testHosts.announceHosts,testHomeRegionName, testServiceName, {
      logger:
        logs:[]
        log:(args...)->
          @logs.push(args)
    })


    @notifier = @discoveryClient.discoveryNotifier
    @logger = @discoveryClient.logger

  it "notifyError, onError", ->
    err = new Error("oh no")
    @notifier.onError (@recievedError)=>
    @notifier.notifyError(err)
    expect(@logger.logs[0]).to.deep.equal [
      "error", "Discovery error: ", err
    ]
    expect(@recievedError).to.equal err

  it "notifyWatchers, onUpdate", ->
    @notifier.onUpdate (@recievedUpdate)=>
    @notifier.notifyWatchers("someUpdate")
    expect(@logger.logs[0]).to.deep.equal [
      "debug", "Discovery update: ", "someUpdate"
    ]
    expect(@recievedUpdate).to.equal "someUpdate"

  it "log()", ->
    @notifier.log "debug", 1, 2, 3
    expect(@logger.logs[0]).to.deep.equal(
      ["debug", 1, 2, 3])

  it "notifyAndReject()", (done)->
    error = new Error("oops")
    @notifier.onError (@notifiedError)=>

    @notifier.notifyAndReject(error).catch (recievedError)=>
      expect(recievedError).to.equal error
      expect(@notifiedError).to.equal error
      done()


