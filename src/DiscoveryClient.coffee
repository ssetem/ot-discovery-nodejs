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
  constructor: (@host, announcementHosts, homeRegionName, serviceName, @options) ->
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
    @serverList = new ServerList @logger, @reconnect
    @announcementIndex = new AnnouncementIndex @serverList
    @discoveryConnector = new DiscoveryConnector @host, @_serviceName, @logger
    @discoveryLongPoller = new DiscoveryLongPoller @_serviceName, @serverList, @announcementIndex, @discoveryNotifier

    @_discoveryAnnouncers = _.map @_announcementHosts, (host) =>
      new DiscoveryAnnouncer @logger, host

    @RETRY_TIMES = 10
    @RETRY_BACKOFF = 1

  onUpdate: (fn) ->
    @discoveryNotifier.onUpdate fb

  onError: (fn) ->
    @discoveryNotifier.onError fn

  find: (service) ->
    @announcementIndex.find service

  findAll: (service) ->
    @announcementIndex.findAll service

  connect: (callback) =>
    @discoveryConnector.connect()
      .then(@saveUpdates)
      .then(@longPollForUpdates)
      .then(@startAnnouncementHeartbeat)
      .then () =>
        return [@host, @serverList.servers]
      .catch (e) =>
        @discoveryNotifier.notifyError e
        throw e
      .nodeify callback, {spread: true}

  reconnect: () ->
    Utils.promiseRetry () =>
      @discoveryConnector.connect()
        .then @saveUpdates
    , @RETRY_TIMES, @RETRY_BACKOFF

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

  getServers: () ->
    @serverList.servers

  getAnnouncements: () ->
    @announcementIndex.getAnnouncements()


module.exports = DiscoveryClient
