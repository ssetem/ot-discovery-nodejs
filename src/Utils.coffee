Promise = require "bluebird"
uuid    = require "node-uuid"
_       = require "lodash"

class Utils

  promiseRetry:(fn, times=Infinity, backoff=500)->
    MAX_BACKOFF = 10 * 1000
    fn().catch (e)=>
      if times < 1
        Promise.reject(e)
      else
        Promise.delay(backoff).then =>
          newBackoff = Math.min(backoff * 2, MAX_BACKOFF)
          @promiseRetry fn, times-1, newBackoff

  invokeAll:(fns, args...)->
    for fn in fns
      fn.apply(null, args)

  generateUUID:()->
    uuid.v4()

  delegateMethods:(target, delegate, methods)->
    for method in methods
      do (method)->
        target[method] = (args...)->
          delegate[method].apply(delegate, args)

  groupPromiseInspections:(inspections)->
    reducer = (acc, inspection)->
      if inspection.isFulfilled()
        acc.fulfilled.push(inspection.value())
      else if inspection.isRejected()
        acc.rejected.push(inspection.reason())
      acc

    _.reduce(
      inspections,
      reducer,
      {fulfilled:[], rejected:[]}
    )

module.exports = new Utils