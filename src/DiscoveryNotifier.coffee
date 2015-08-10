Promise = require "bluebird"
Utils   = require "./Utils"
_ = require "lodash"

class DiscoveryNotifier

  constructor: (@logger) ->
    @errorHandlers = [
      @logger.log.bind(@logger, "error", "Discovery error: ")
    ]
    @watchers = [
      @logger.log.bind(@logger, "debug", "Discovery update: ")
    ]

  notifyError: (error) ->
    _.invoke(@errorHandlers, _.call, null, error)

  notifyWatchers: (body) ->
    _.invoke(@watchers, _.call, null, body)

  onUpdate:(fn)->
    @watchers.push(fn)

  onError:(fn)->
    @errorHandlers.push(fn)

module.exports = DiscoveryNotifier
