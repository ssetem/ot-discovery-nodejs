Promise = require "bluebird"



module.exports = new class Utils


  promiseRetry:(fn, times=Infinity, backoff=1)->
    self = this
    fn().catch (e)=>
      if times is 0
        Promise.reject(e)
      else
        Promise.delay(backoff).then ->
          newBackoff = Math.min(backoff * 2, 10240)
          self.retryWithBackoff fn, newBackoff, times-1

  invokeAll:(fns, args...)->
    for fn in fns
      fn.apply(null, args)
