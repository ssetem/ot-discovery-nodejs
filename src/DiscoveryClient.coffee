DiscoveryConnector  = require "./DiscoveryConnector"
AnnouncementIndex   = require "./AnnouncementIndex"
DiscoveryAnnouncer  = require "./DiscoveryAnnouncer"
DiscoveryNotifier   = require "./DiscoveryNotifier"
DiscoveryLongPoller = require "./DiscoveryLongPoller"
ServerList          = require "./ServerList"
Utils               = require "./Utils"
Promise             = require "bluebird"

class DiscoveryClient

  constructor:(@host, @options)->
    @HEARTBEAT_INTERVAL_MS = 10 * 1000

    @logger = @options?.logger or require "./ConsoleLogger"
    @discoveryNotifier    = new DiscoveryNotifier(@logger)
    @serverList           = new ServerList(@logger)
    @announcementIndex    = new AnnouncementIndex(@serverList, @discoveryNotifier)
    @discoveryConnector   = new DiscoveryConnector(@host, @logger, @discoveryNotifier)
    @discoveryLongPoller  = new DiscoveryLongPoller(@serverList, @announcementIndex, @discoveryNotifier, @reconnect)
    @discoveryAnnouncer   = new DiscoveryAnnouncer(@logger, @serverList, @discoveryNotifier, @reconnect)

    Utils.delegateMethods @,  @discoveryNotifier, [
      "log", "onUpdate", "onError", "notifyAndReject"
      "notifyError", "notifyWatchers"
    ]


    Utils.delegateMethods @, @announcementIndex, [
      "find", "findAll"
    ]



  connect:(callback)=>
    @discoveryConnector.connect()
      .then(@saveUpdates)
      .then(@longPollForUpdates)
      .then(@startAnnouncementHeartbeat)
      .then ()=>
        if callback
          return callback null, @host, @serverList.servers
        else
          @servers
      .catch (e)->
        if callback
          return callback(e)
        else
          Promise.reject(e)

  reconnect:(callback)=>
    @connect(callback)

  stopAnnouncementHeartbeat:()=>
    if @heartbeatIntervalId
      clearInterval(@heartbeatIntervalId)

  startAnnouncementHeartbeat:()=>
    @stopAnnouncementHeartbeat()

    @heartbeatIntervalId = setInterval(
      @discoveryAnnouncer.pingAllAnnouncements
      @HEARTBEAT_INTERVAL_MS
    )
    return

  announce:(announcement, callback)->
    @discoveryAnnouncer.announce(
      announcement, callback)

  unannounce:(announcement, callback)->
    @discoveryAnnouncer.unannounce(
      announcement, callback)

  dispose:()->
    @stopAnnouncementHeartbeat()
    @discoveryLongPoller.stopPolling()

  saveUpdates:(update)=>
    @announcementIndex.processUpdate(update)

  longPollForUpdates:()=>
    @discoveryLongPoller.startPolling()
    return

  getServers:()->
    @serverList.servers

  getAnnouncements:()->
    @announcementIndex.announcements


module.exports = DiscoveryClient