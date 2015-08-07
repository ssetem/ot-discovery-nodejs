DiscoveryConnector = require "./DiscoveryConnector"
AnnouncementIndex = require "./AnnouncementIndex"
DiscoveryAnnouncer = require "./DiscoveryAnnouncer"
DiscoveryNotifier = require "./DiscoveryNotifier"
DiscoveryLongPoller = require "./DiscoveryLongPoller"
ServerList = require "./ServerList"
Utils = require "./Utils"
Promise = require "bluebird"
_ = require "lodash"


  # host = 'http://discovery.discoservice.com'
  #
  # announcementHosts - ['http://discovery_server2.org', 'http://discovery_server3.org']
  #
  # homeRegionName = 'something-prod-etc' - used to set environement field in announce posts
  # serviceName = 'myServiceName' - needed for discovery apiv2 - will be sent in the watch request to tell server we are a api2 client
  # options = {
  #   logger = console.log...etc
  #   apiv2Strict = true - will force apiv2 constructor params and throw errors if not met, otherwise allow apiv1 fallback
  # }
  # NOTE: there is some interface backwards campatabiltiy with the disco api v1**
  # so (host, options) is valid. and will result in the old behaviour

class DiscoveryClient
  constructor:(@host, announcementHosts, homeRegionName, serviceName, @options)->
    if @options?.apiv2Strict
      unless Array.isArray announcementHosts
        errmsg = "announcementHosts must be an array."
      unless typeof homeRegionName == "string"
        errmsg = "homeRegionName must be a valid string."
      unless typeof serviceName == "string"
        errmsg = "serviceName must be a valid string."

      if errmsg
        throw new Error errmsg

    if Array.isArray announcementHosts
      @_announcementHosts = announcementHosts
    else
      @options = if (announcementHosts is Object)? then announcementHosts else @options
      @_announcementHosts = [@host]

    @_homeRegionName = homeRegionName || null
    @_serviceName = serviceName || null

    checkHostName = (hostname) ->
      if hostname.indexOf("http://") > 0
        throw new Error "announcementHost should not contain http:// - use direct host name"

    checkHostName @host
    _.forEach @_announcementHosts, checkHostName


    @logger = @options?.logger or require "./ConsoleLogger"
    @discoveryNotifier = new DiscoveryNotifier @logger
    @serverList = new ServerList @logger
    @announcementIndex = new AnnouncementIndex @serverList
    @discoveryConnector = new DiscoveryConnector @host, @_serviceName, @logger, @discoveryNotifier
    @discoveryLongPoller = new DiscoveryLongPoller @_serviceName, @serverList, @announcementIndex, @discoveryNotifier, @reconnect

    @_discoveryAnnouncers = _.map @_announcementHosts, (host) =>
      new DiscoveryAnnouncer @logger, host, @discoveryNotifier

    Utils.delegateMethods @, @discoveryNotifier, [
      "log", "onUpdate", "onError", "notifyAndReject"
      "notifyError", "notifyWatchers"
    ]

    Utils.delegateMethods @, @announcementIndex, [
      "find", "findAll"
    ]

  connect: (callback) =>
    @discoveryConnector.connect()
      .then(@saveUpdates)
      .then(@longPollForUpdates)
      .then(@startAnnouncementHeartbeat)
      .then () =>
        if callback
          return callback null, @host, @serverList.servers
        else
          @servers
      .catch (e) ->
        if callback
          return callback(e)
        else
          Promise.reject(e)

  reconnect: (callback) =>
    @connect(callback)

  stopAnnouncementHeartbeat: () =>
    _.invoke @_discoveryAnnouncers, "stopAnnouncementHeartbeat"

  startAnnouncementHeartbeat: () =>
    _.invoke @_discoveryAnnouncers, "startAnnouncementHeartbeat"

  announce: (announcement, callback) =>
    if @_homeRegionName
      announcement.environment = @_homeRegionName

    announcedPromises = _.map @_discoveryAnnouncers, (announcer) ->
      announcer.announce announcement
    Promise.all(announcedPromises).catch (e) =>
      @discoveryNotifier.notifyError(e)
      throw e
    .nodeify(callback)

  unannounce: (announcements, callback) =>
    unannouncedPromises = _.map _.zip(@_discoveryAnnouncers, announcements),
      (announcementPair) ->
        announcementPair[0].unannounce announcementPair[1]

    Promise.all(unannouncedPromises).catch (e) =>
      @discoveryNotifier.notifyError(e)
      throw e
    .nodeify(callback)

  dispose: () ->
    @stopAnnouncementHeartbeat()
    @discoveryLongPoller.stopPolling()

  saveUpdates: (update) =>
    @announcementIndex.processUpdate(update)

  longPollForUpdates: () =>
    @discoveryLongPoller.startPolling()
    return

  getServers: () ->
    @serverList.servers

  getAnnouncements: () ->
    @announcementIndex.getAnnouncements()


module.exports = DiscoveryClient
