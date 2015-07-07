DiscoveryConnector = require "./DiscoveryConnector"
AnnouncementIndex = require "./AnnouncementIndex"
DiscoveryAnnouncer = require "./DiscoveryAnnouncer"
DiscoveryLongPoller = require "./DiscoveryLongPoller"
ServerList = require "./ServerList"
Utils = require "./Utils"

class DiscoveryClient

  constructor:(@host, @options)->

    @logger = @options?.logger or require "ot-logger"
    @announcementIndex = new AnnouncementIndex(@)
    @serverList = new ServerList(@)
    @discoveryConnector = new DiscoveryConnector(@)
    @discoveryLongPoller = new DiscoveryLongPoller(@)
    @discoveryAnnouncer = new DiscoveryAnnouncer(@)
    @errorHandlers = [
      @logger.log.bind(@logger, "error", "Discovery error: ")
    ]
    @watchers = [
      @logger.log.bind(@logger, "debug", "Discovery update: ")
    ]

  connect:(callback)->
    @discoveryConnector.connect()
      .then(@saveUpdates)
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

  saveUpdates:(update)=>
    console.log update
    @announcementIndex.processUpdate(update)

  longPollForUpdates:()=>
    @discoveryLongPoller.startPolling()

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

  onUpdate:(fn)->
    @watchers.push(fn)

  onError:(fn)->
    @errorHandlers.push(fn)

  log:(args...)->
    @logger.log.apply(@logger, args)

module.exports = DiscoveryClient