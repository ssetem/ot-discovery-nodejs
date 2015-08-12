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

  it "delegateMethods", ->
    delegate = {
      foo:(@fooArgs...)=>
    }

    target = {

    }
    Utils.delegateMethods(target, delegate, ["foo"])
    target.foo(1,2,3)
    expect(@fooArgs).to.deep.equal [1,2,3]

  it "groupPromiseInspections()", (done)->
    promises = [
      Promise.resolve(1)
      Promise.resolve(2)
      Promise.reject(3)
      Promise.reject(4)
    ]
    Promise.settle(promises).then(Utils.groupPromiseInspections)
      .then (groups)->
        expect(groups).to.deep.equal {
          fulfilled: [ 1, 2 ],
          rejected: [ 3, 4 ]
        }
        done()




