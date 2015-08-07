Promise = require "bluebird"
Errors = require "./Errors"
Utils = require "./Utils"
ServerList = require "./ServerList"
_ = require "lodash"
request = Promise.promisify require("request")

module.exports = class DiscoveryAnnouncer

  # @announcementHost should contain a hostname only
  constructor: (@logger, @announcementHost, @discoveryNotifier) ->
    @ANNOUNCED_ATTEMPTS = 20
    @INITIAL_BACKOFFS = 500
    @_announcedRecords = {}
    @HEARTBEAT_INTERVAL_MS = 10 * 1000
    @serverList = new ServerList @logger

  pingAllAnnouncements: () =>
    Promise.settle(_.map(@_announcedRecords, @attemptAnnounce) )
      .then(Utils.groupPromiseInspections)
      .then (resultGroups) =>
        if resultGroups.rejected?.length > 0
          @logger.log "error", "#{resultGroups.rejected?.length} announcements failed"
        resultGroups.fulfilled

  announce: (announcement) ->
    Utils.promiseRetry(
      @attemptAnnounce.bind(@, announcement)
      @ANNOUNCED_ATTEMPTS
      @INITIAL_BACKOFFS
    )

  removeAnnouncement: (announcement) =>
    delete @_announcedRecords[announcement.announcementId]

  attemptAnnounce: (announcement) =>
    announcement.announcementId or= Utils.generateUUID()
    @getServer()
      .catch (getServerError) =>
        @discoveryNotifier.notifyAndReject new Error("Couldn't watch server #{@announcementHost}")
      .then (server) =>
        @logger.log "debug", "Announcing " + JSON.stringify(announcement)
        url = server + "/announcement"

        request
          url: url
          method: "POST"
          json: true
          body: announcement
        .catch (error) =>
          @serverList.dropServer server
          @discoveryNotifier.notifyAndReject error
        .spread @handleResponse

  handleResponse: (response, body) =>
    unless response?.statusCode is 201
      return @discoveryNotifier.notifyAndReject(
        new Error("During announce, bad status code #{response.statusCode}:#{JSON.stringify(body)}") )

    announcement = body
    @logger.log "info", "Announced as ", JSON.stringify(announcement)
    @_doAddAnnouncement announcement
    return announcement

  unannounce: (announcement) ->
    @attemptUnannounce(announcement)

  _doAddAnnouncement: (announcement) =>
    @_announcedRecords[announcement.announcementId] = announcement

  getServer: () =>
    server = @serverList.getRandom()
    if server
      Promise.resolve server
    else
      url = "http://#{@announcementHost}/watch"
      request
        url:url
        json:true
      .spread (response, body) =>
        servers = _.chain(body.updates)
          .where({serviceType:"discovery"})
          .pluck("serviceUri")
          .value()

        @serverList.addServers servers

        returnedServer = @serverList.getRandom()

        if returnedServer
          Promise.resolve returnedServer
        else
          Promise.reject new Error("No servers after watch")

  attemptUnannounce: (announcement) =>
    @getServer().then (server)=>
      url = "#{server}/announcement/#{announcement.announcementId}"
      request
        url: url
        method: "DELETE"
      .spread (response, body) =>
        @removeAnnouncement(announcement)
        @logger.log "info", "Unannounce DELETE '#{url}' returned #{response.statusCode}:#{JSON.stringify(body)}"
      .catch (error) =>
        @serverList.dropServer server
        @discoveryNotifier.notifyAndReject error

  startAnnouncementHeartbeat: () =>
    @stopAnnouncementHeartbeat()
    @_AnnouncementHeartbeatInterval = setInterval @pingAllAnnouncements, @HEARTBEAT_INTERVAL_MS

  stopAnnouncementHeartbeat: () =>
    if @_AnnouncementHeartbeatInterval
      clearInterval @_AnnouncementHeartbeatInterval
    @_AnnouncementHeartbeatInterval = null
