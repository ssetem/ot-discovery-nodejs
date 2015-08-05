Promise = require "bluebird"
Errors = require "./Errors"
RequestPromise = require "./RequestPromise"
Utils = require "./Utils"
ServerList = require "./ServerList"
_ = require "lodash"

module.exports = class DiscoveryAnnouncer

  constructor: (@logger, @announcementHost, @discoveryNotifier) ->
    @ANNOUNCED_ATTEMPTS = 20
    @INITIAL_BACKOFFS = 500
    @_announcedRecords = {}
    @HEARTBEAT_INTERVAL_MS = 10 * 1000
    @serverList = new ServerList @logger

  pingAllAnnouncements: () =>
    announcements = @getAnnouced()
    Promise.settle(_.map(announcements, @attemptAnnounce) )
      .then(Utils.groupPromiseInspections)
      .then (resultGroups) =>
        if resultGroups.rejected?.length > 0
          @logger.log "error", "#{resultGroups.rejected?.length} announcements failed"
        resultGroups.fulfilled

  getAnnouced: () =>
    @_announcedRecords

  announce: (announcement, callback) =>
    Utils.promiseRetry(
      @attemptAnnounce.bind(@, announcement)
      @ANNOUNCED_ATTEMPTS
      @INITIAL_BACKOFFS
    ).nodeify(callback)

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

        RequestPromise({
          url: url
          method: "POST"
          json: true
          body: announcement
        }).catch((error) =>
          @serverList.dropServer server
          @discoveryNotifier.notifyAndReject error
        ).then(@handleResponse)

  handleResponse: (response) =>
    unless response?.statusCode is 201
      return @discoveryNotifier.notifyAndReject(
        new Error("During announce, bad status code #{response.statusCode}:#{JSON.stringify(response.body)}") )

    announcement = response.body
    @logger.log "info", "Announced as ", JSON.stringify(announcement)
    @_doAddAnnouncement announcement
    return announcement

  unannounce: (announcementId, callback) ->
    @attemptUnannounce(announcementId)
      .nodeify(callback)

  _doAddAnnouncement: (announcement) =>
    @_announcedRecords[announcement.announcementId] = announcement

  getServer: () =>
    server = @serverList.getRandom()
    if server
      Promise.resolve server
    else
      url = @announcementHost + "/watch"
      return RequestPromise(
        url:url
        json:true
      ).then (response) =>
        servers = _.chain(response.body.updates)
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
      RequestPromise({
        url: url
        method: "DELETE"
      } ).then (response) =>
        @removeAnnouncement(announcement)
        @logger.log("info", "Unannounce DELETE '#{url}' returned #{response.statusCode}:#{JSON.stringify(response.body)}")
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
