DiscoveryConnector = require "./DiscoveryConnector"
AnnouncementIndex = require "./AnnouncementIndex"
DiscoveryAnnouncer = require "./DiscoveryAnnouncer"
DiscoveryLongPoller = require "./DiscoveryLongPoller"
ServerList = require "./ServerList"
Utils = require "./Utils"
Promise = require "bluebird"

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
      .then ()=>
        if callback
          return callback null, @host, @serverList.servers
        else
          @servers
      .catch (e)=>
        if callback
          return callback(e)
        else
          Promise.reject(e)

  stopAnnouncementHeartbeat:()=>
    if @heartbeatIntervalId
      clearInterval(@heartbeatIntervalId)

  startAnnouncementHeartbeat:()=>
    @stopAnnouncementHeartbeat()
    heartbeatIntervalMs = 10 * 1000
    @heartbeatIntervalId = setInterval(
      @discoveryAnnouncer.pingAllAnnouncements
      heartbeatIntervalMs
    )
    return

  reconnect:()->
    @connect()

  dispose:()->
    @stopAnnouncementHeartbeat()
    @discoveryLongPoller.stopPolling()

  getHostAndServers:()=>
    [@host, @serverList.servers]

  saveUpdates:(update)=>
    @announcementIndex.processUpdate(update)

  longPollForUpdates:()=>
    @discoveryLongPoller.startPolling()
    return

  getServers:()->
    @serverList.servers

  getAnnouncements:()->
    @announcementIndex.announcements

  announce:(announcement, callback)->
    @discoveryAnnouncer.announce(
      announcement, callback)

  unannounce:(announcement, callback)->
    @discoveryAnnouncer.unannounce(
      announcement, callback)

  find:(predicate)->
    @announcementIndex.find(predicate)

  findAll:(predicate)->
    @announcementIndex.findAll(predicate)

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