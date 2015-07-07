DiscoveryConnector = require "DiscoveryConnector"
AnnouncementIndex = require "AnnouncementIndex"
DiscoveryAnnouncer = require "DiscoveryAnnouncer"
DisoveryLongPoller = require "DisoveryLongPoller"
ServerList = require "ServerList"
Utils = require "Utils"

class DiscoveryClient

  constructor:(@host, @options)->

    @logger = @options?.logger or require "ot-logger"
    @announcementIndex = new AnnouncementIndex(@)
    @serverList = new ServerList(@)
    @discoveryConnector = new DiscoveryConnector(@)
    @discoveryLongPoller = new DiscoveryLongPoller(@)
    @discoveryAnnouncer = new DiscoveryAnnouncer(@)
    @errorHandlers = []
    @watchers = []

  connect:(callback)->
    discoveryConnector.connect()
      .then(@longPollForUpdates)
      .then(@startAnnouncementHeartbeat)
      .nodeify(callback)

  startAnnouncementHeartbeat:()=>
    if @heartbeatIntervalId
      clearInterval(@heartbeatIntervalId)
    heartbeatIntervalMs = 10 * 1000
    @heartbeatIntervalId = setInterval(
      @discoveryAnnouncer.pingAllAnnouncements
      heartbeatIntervalMs
    )

  reconnect:()->
    @connect()

  longPollForUpdates:()=>
    @discoveryLongPoller.schedulePoll()

  announce:(announcement, callback)->
    @discoveryAnnouncer.announce(
      announcement, callback)

  unannounce:(announcement, callback)->
    @discoveryAnnouncer.unannounce(
      announcement, callback)

  notifyError:(error)->
    Utils.invokeAll(@errorHandlers, error)

  notifyWatchers:(body)->
    Utils.invokeAll(@watchers, body)

  log:(args...)->
    @logger.log.apply(@logger, args)

module.exports = DiscoveryClient