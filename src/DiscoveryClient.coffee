AnnouncementIndex = require "./AnnouncementIndex"
DiscoveryAnnouncer = require "./DiscoveryAnnouncer"
DiscoveryNotifier = require "./DiscoveryNotifier"
DiscoveryWatcher = require "./DiscoveryWatcher"
ServerList = require "./ServerList"
Utils = require "./Utils"
Promise = require "bluebird"
_ = require "lodash"


# constructor
# DiscoveryClient(host, announcementHosts, homeRegionName, serviceType,
#   options)
# @param = {String} host The hostname to the discovery server.
# @param {Array} [annoucementHosts] An array of announcement host names
#   multiple for announcing in multiple disco regions.
#   If not provided will use host.
#   Host is not announced to by design.  Explicity include the discovery
#     server in the announcementHosts if you wish to announce to it.
#
# @param {string} [homeRegionName] The name of hosted region your sevice is in
# @param {String} [serviceType] The name of the service you will announce as.
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
  constructor: (@host, announcementHosts, homeRegionName, serviceType, @options) ->
    arglength = arguments.length
    unless (arglength >= 1 and arglength <= 2) or (arglength >= 4 and arglength <= 5)
      throw new Error "Incorrect number of parameters: #{arglength}, DiscoveryClient expects 1(+1) or 4(+1)"

    if not @options and typeof announcementHosts == "object" and not Array.isArray announcementHosts
      @options = announcementHosts
      @_announcementHosts = [@host]
    else
      @_announcementHosts = announcementHosts

    @_homeRegionName = homeRegionName || null
    @_serviceType = serviceType || null

    if arguments.length >= 4
      unless Array.isArray announcementHosts # strict mode - checking announcementHosts even after massaging @_announcementHosts
        throw new  Error "announcementHosts must be an array of hostnames(strings)."
      unless typeof @_homeRegionName == "string"
        throw new  Error "homeRegionName must be a valid string."
      unless typeof @_serviceType == "string"
        throw new  Error "serviceType must be a valid string."

    checkHostName = (hostname) ->
      if hostname.indexOf("http://") != -1
        throw new Error "host/announcementhost should not contain http:// - use direct host name"

    checkHostName @host
    _.each @_announcementHosts, checkHostName

    @logger = @options?.logger or require "./ConsoleLogger"
    @discoveryNotifier = new DiscoveryNotifier @logger
    @serverList = new ServerList @logger, @reconnect
    @announcementIndex = new AnnouncementIndex
    @discoveryWatcher = new DiscoveryWatcher

    @_discoveryAnnouncers = _.map @_announcementHosts, (host) =>
      new DiscoveryAnnouncer @logger, host

    @RETRY_TIMES = 10
    @RETRY_BACKOFF = 1

  onUpdate: (fn) ->
    @discoveryNotifier.onUpdate fn

  onError: (fn) ->
    @discoveryNotifier.onError fn

  find: (service) ->
    @announcementIndex.find service

  findAll: (service) ->
    @announcementIndex.findAll service

  connect: (callback) =>
    @discoveryWatcher.watch @host
      .spread @saveUpdates
      .then () =>
        @polling = true
        #fire after completing the connect
        process.nextTick () =>
          @schedulePoll()
        return [@host, @serverList.servers]
      .catch (e) =>
        @discoveryNotifier.notifyError e
        throw e
      .nodeify callback, {spread: true}

  reconnect: () =>
    Utils.promiseRetry () =>
      @discoveryWatcher.watch @host
        .spread (statusCode, updates) =>
          @saveUpdates statusCode, updates
          @announcementIndex.getDiscoveryServers()
    , @RETRY_TIMES, @RETRY_BACKOFF

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
    announcement = _.extend {}, announcement
    if @_homeRegionName
      announcement.environment = @_homeRegionName

    announcedPromises = _.map @_discoveryAnnouncers, (announcer) ->
      # we need to clone each announcement so each announcement in each region
      # gets a new announcementId
      announcer.announce _.extend({}, announcement)

    Promise.all(announcedPromises).catch (e) =>
      @discoveryNotifier.notifyError(e)
      throw e
    .nodeify(callback)

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

  # disconnect - will shut down announcement heartbeats and stop any long polls
  #    that are currently active or queued.  This is critical if you plan to
  #    start and stop discovery or you might be left with open connections.
  #
  disconnect: () =>
    _.invoke @_discoveryAnnouncers, 'stopHeartbeat'
    @polling = false
    @discoveryWatcher.abort()

  saveUpdates: (statusCode, update) =>
    if statusCode is 204
      throw new Error 'expected a full update on connect'
    else
      @announcementIndex.processUpdate update
      @serverList.addServers @announcementIndex.getDiscoveryServers()

  schedulePoll: () =>
    return unless @polling
    @poll().finally @schedulePoll

  poll: () =>
    @serverList.getRandom()
      .then (server) =>
        @discoveryWatcher.watch server, @serviceType, @announcementIndex.index + 1
          .spread (statusCode, update) =>
            if statusCode isnt 204
              @saveUpdates statusCode, update
              @discoveryNotifier.notifyWatchers update
          .catch (error) =>
            @serverList.dropServer server
            @discoveryNotifier.notifyError error
            throw error

module.exports = DiscoveryClient
