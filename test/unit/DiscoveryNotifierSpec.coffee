DiscoveryNotifier = require "#{srcDir}/DiscoveryNotifier"
sinon = require "sinon"

describe "DiscoveryNotifier", ->
  beforeEach ->
    @logger =
      log: sinon.spy()
    
    @notifier = new DiscoveryNotifier @logger

  it "notifyError, onError", ->
    err = new Error("oh no")
    @notifier.onError (@recievedError)=>
    @notifier.notifyError(err)
    expect(@logger.log.calledWithMatch("error", "Discovery error: ", err))
      .to.be.ok
    expect(@recievedError).to.equal err

  it "notifyWatchers, onUpdate", ->
    @notifier.onUpdate (@recievedUpdate)=>
    @notifier.notifyWatchers("someUpdate")
    expect(@logger.log.calledWithMatch("debug", "Discovery update: ", "someUpdate"))
      .to.be.ok
    expect(@recievedUpdate).to.equal "someUpdate"

  it "notifyAndReject()", (done)->
    error = new Error("oops")
    @notifier.onError (@notifiedError)=>

    @notifier.notifyAndReject(error).catch (recievedError)=>
      expect(recievedError).to.equal error
      expect(@notifiedError).to.equal error
      done()


