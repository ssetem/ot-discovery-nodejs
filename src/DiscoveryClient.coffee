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
    arglength = arguments.length
    unless (arglength >= 1 and arglength <= 2) or (arglength >= 4 and arglength <= 5)
      throw new Error "Incorrect number of parameters: #{arglength}, DiscoveryClient expects 1(+1) or 4(+1)"

    unless @options?
      if typeof announcementHosts == "object" and not Array.isArray announcementHosts
        @options = announcementHosts

    @_announcementHosts = if Array.isArray announcementHosts then announcementHosts else [@host]
    @_homeRegionName = homeRegionName || null
    @_serviceName = serviceName || null

    if arguments.length >= 4
      unless Array.isArray announcementHosts # strict mode - checking announcementHosts even after massaging @_announcementHosts
        throw new  Error "announcementHosts must be an array of hostnames(strings)."
      unless typeof @_homeRegionName == "string"
        throw new  Error "homeRegionName must be a valid string."
      unless typeof @_serviceName == "string"
        throw new  Error "serviceName must be a valid string."

    checkHostName = (hostname) ->
      if hostname.indexOf("http://") != -1
        throw new Error "host/announcementhost should not contain http:// - use direct host name"

    checkHostName @host
    _.each @_announcementHosts, checkHostName

    @logger = @options?.logger or require "./ConsoleLogger"
    @discoveryNotifier = new DiscoveryNotifier @logger
    @serverList = new ServerList @logger, @reconnect
    @announcementIndex = new AnnouncementIndex @serverList
    @discoveryConnector = new DiscoveryConnector @host, @_serviceName, @logger
    @discoveryLongPoller = new DiscoveryLongPoller @_serviceName, @serverList, @announcementIndex, @discoveryNotifier

    @_discoveryAnnouncers = _.map @_announcementHosts, (host) =>
      new DiscoveryAnnouncer @logger, host

    Utils.delegateMethods @, @discoveryNotifier, [
      "onUpdate", "onError"
    ]

    Utils.delegateMethods @, @announcementIndex, [
      "find", "findAll"
    ]

    @RETRY_TIMES = 10
    @RETRY_BACKOFF = 1

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
