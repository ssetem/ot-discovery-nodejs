Promise = require "bluebird"
uuid    = require "node-uuid"

class Utils

  promiseRetry:(fn, times=Infinity, backoff=500)->
    self = this
    fn().catch (e)->
      if times is 0
        Promise.reject(e)
      else
        Promise.delay(backoff).then ->
          newBackoff = Math.min(backoff * 2, 10240)
          self.promiseRetry fn, times-1, newBackoff

  invokeAll:(fns, args...)->
    for fn in fns
      fn.apply(null, args)

  generateUUID:()->
    uuid.v4()

module.exports = new Utils