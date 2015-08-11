Promise = require "bluebird"
uuid    = require "node-uuid"
_       = require "lodash"

class Utils

  promiseRetry: (fn, times, backoff) ->
    MAX_BACKOFF = 10 * 1000
    fn().catch (e) =>
      if times < 1
        throw e
      else
        Promise.delay(backoff).then =>
          newBackoff = Math.min(backoff * 2, MAX_BACKOFF)
          @promiseRetry fn, times-1, newBackoff

  generateUUID:()->
    uuid.v4()

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
