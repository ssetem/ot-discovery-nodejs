Promise = require "bluebird"
Utils = require "./Utils"
ServerList = require "./ServerList"
DiscoveryWatcher = require "./DiscoveryWatcher"
_ = require "lodash"
request = Promise.promisify require("request")

module.exports = class DiscoveryAnnouncer
  # @announcementHost should contain a hostname only
  constructor: (@logger, @announcementHost) ->
    @_announcedRecords = {}
    @HEARTBEAT_INTERVAL_MS = 10 * 1000
    @watcher = new DiscoveryWatcher
    @serverList = new ServerList @logger, @connect

  connect: () =>
    @watcher.watch @announcementHost
      .spread (statusCode, body) ->
        if statusCode is 204
          throw new Error "announce expected a full update"
        else
          _.chain body.updates
            .where {serviceType: "discovery"}
            .pluck "serviceUri"
            .value()

  pingAllAnnouncements: () =>
    Promise.settle _.map(@_announcedRecords, @refreshAnnouncement)
      .then Utils.groupPromiseInspections
      .then (resultGroups) =>
        if resultGroups.rejected.length > 0
          @logger.log "error", "#{resultGroups.rejected.length} announcements failed"
        resultGroups.fulfilled

  announce: (announcement) =>
    announcement.announcementId or= Utils.generateUUID()
    # add the announcement to the announcement records now
    # even if the post fails, we will retry it as part of pingAllAnnouncements
    @_announcedRecords[announcement.announcementId] = announcement
    @updateHeartbeat()
    @refreshAnnouncement announcement

  refreshAnnouncement: (announcement) =>
    @serverList.getRandom()
      .then (server) =>
        url = server + "/announcement"

        @logger.log "debug", "Announcing to ${url}" + JSON.stringify(announcement)

        request
          url: url
          method: "POST"
          json: true
          body: announcement
        .spread @handleResponse
        .catch (error) =>
          @serverList.dropServer server
          throw error

  handleResponse: (response, body) =>
    unless response.statusCode is 201
      throw new Error("During announce, bad status code #{response.statusCode}:#{JSON.stringify(body)}")

    announcement = body
    @logger.log "info", "Announced as ", JSON.stringify(announcement)
    announcement

  unannounce: (announcement) ->
    #if we already unannounced successfully, do nothing.
    return Promise.resolve() unless @_announcedRecords[announcement.announcementId]

    @serverList.getRandom()
      .then (server) =>
        url = "#{server}/announcement/#{announcement.announcementId}"
        request
          url: url
          method: "DELETE"
        .spread (response, body) =>
          unless response.statusCode in [200, 204]
            throw new Error "unable to unannounce bad status code #{response.statusCode}:#{JSON.stringify(body)} #{server}"
          delete @_announcedRecords[announcement.announcementId]
          @updateHeartbeat()
          @logger.log "info", "Unannounce DELETE '#{url}' " +
            "returned #{response.statusCode}:#{JSON.stringify(body)}"
          return
        .catch (e) =>
          @serverList.dropServer server
          throw e

  updateHeartbeat: () =>
    if not _.isEmpty @_announcedRecords
      if not @heartbeatInterval
        @heartbeatInterval = setInterval @pingAllAnnouncements, @HEARTBEAT_INTERVAL_MS
    else
      @stopHeartbeat()

  stopHeartbeat: () ->
    clearInterval @heartbeatInterval
    @heartbeatInterval = null
