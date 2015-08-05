Promise = require "bluebird"
Utils   = require "./Utils"


class DiscoveryNotifier

  constructor:(@logger)->
    @errorHandlers = [
      @logger.log.bind(@logger, "error", "Discovery error: ")
    ]
    @watchers = [
      @logger.log.bind(@logger, "debug", "Discovery update: ")
    ]

  notifyError:(error)->
    Utils.invokeAll(@errorHandlers, error)

  notifyWatchers:(body)->
    Utils.invokeAll(@watchers, body)

  onUpdate:(fn)->
    @watchers.push(fn)

  onError:(fn)->
    @errorHandlers.push(fn)

  notifyAndReject:(error)=>
    @notifyError(error)
    return Promise.reject(error)


module.exports = DiscoveryNotifier
