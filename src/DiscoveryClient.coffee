DiscoveryConnector = require "./DiscoveryConnector"
AnnouncementIndex = require "./AnnouncementIndex"
DiscoveryAnnouncer = require "./DiscoveryAnnouncer"
DiscoveryNotifier = require "./DiscoveryNotifier"
DiscoveryLongPoller = require "./DiscoveryLongPoller"
ServerList = require "./ServerList"
Utils = require "./Utils"
Promise = require "bluebird"
_ = require "lodash"


# constructor
# DiscoveryClient(host, announcementHosts, homeRegionName, serviceName,
#   options)
# @param = {String} host The hostname to the discovery server.
# @param {Array} [annoucementHosts] An array of announcement host names
#   multiple for announcing in multiple disco regions.
#   If not provided will use host.
#   Host is not announced to by design.  Explicity include the discovery
#     server in the announcementHosts if you wish to announce to it.
#
# @param {string} [homeRegionName] The name of hosted region your sevice is in
# @param {String} [serviceName] The name of the service you will announce as.
# @param {Object} [options] Options argument that takes the following:
#      {
#        logger: { log: function(level, message){}}
#      }
# @returns {Object} Returns a discovery client object.
#
#
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


 # @param = {Object} announcement - announcement object:
 #   {
 #      serviceType:'myServiceTypeName',
 #      serviceUri:'http://myuri.com'
 #   }
 # @param {function(err, announcedItemLeases)} callback Node style callback
 #   Please note that annoucedItemLeases is required to hold onto (UNMODIFIED)
 #     if you plan to use unannounce.
 #
 # @returns {Promise} Returns a promise object that resolves with the itemLeases.
 #
 # NOTE: Announce will error unless the endpoint specified in serviceUri responds
 #   to OPTION / with a valid response
 #
  announce: (announcement, callback) =>
    if @_homeRegionName
      announcement.environment = @_homeRegionName

    announcedPromises = _.map @_discoveryAnnouncers, (announcer) ->
      announcer.announce announcement
<<<<<<< HEAD
    Promise.all(announcedPromises).catch (e) =>
      @discoveryNotifier.notifyError(e)
      throw e
    .nodeify(callback)
=======
    Promise.all(announcedPromises).nodeify(callback)
>>>>>>> 011f4c4ca35a5f543d16670427ff93880ffa6615


 # @param = {Array} announcedItemLeases - announcement array directly from
 #   DiscoveryClient.announce callback - MUST NOT BE MODIFIED- INCLUDING ORDER!
 # @param {function(err)} callback Node style callback
 #
 # @returns {Promise} Returns a promise object that has an empty resolve.
 #
  unannounce: (announcedItemLeases, callback) =>
    unannouncedPromises = _.map _.zip(@_discoveryAnnouncers, announcedItemLeases),
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
