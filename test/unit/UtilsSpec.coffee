Utils   = require("#{srcDir}/Utils")
Promise = require("bluebird")

describe "Utils", ->

  beforeEach ->


  it "Utils should exist", ->
    expect(Utils).to.exist


  it "promiseRetry() - fail", (done)->
    callCount = 0
    fn = ()->
      callCount++
      Promise.reject("Error:#{callCount}")

    Utils.promiseRetry(fn, 4, 1).catch (e)->
      expect(e).to.equal("Error:5")
      done()

  it "promiseRetry() - success", (done)->
    callCount = 0
    fn = ()->
      callCount++
      if callCount < 10
        Promise.reject("Error:#{callCount}")
      else
        Promise.resolve("success:#{callCount}")

    Utils.promiseRetry(fn, Infinity, 1).then (result)->
      expect(result).to.equal("success:10")
      done()



  it "invokeAll()", ->
    str = ""

    fn = (args...)->
      str += args.join("")

    fns = [fn, fn]

    Utils.invokeAll(fns, "a", "b")

    expect(str).to.equal "abab"