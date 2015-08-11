Promise = require "bluebird"
Errors = require "./Errors"
Utils = require "./Utils"
ServerList = require "./ServerList"
DiscoveryConnector = require "./DiscoveryConnector"
_ = require "lodash"
request = Promise.promisify require("request")

module.exports = class DiscoveryAnnouncer
  # @announcementHost should contain a hostname only
  constructor: (@logger, @announcementHost) ->
    @_announcedRecords = {}
    @HEARTBEAT_INTERVAL_MS = 10 * 1000
    @connector = new DiscoveryConnector @announcementHost, null, @logger
    @serverList = new ServerList @logger, @connect

  connect: () =>
    @connector.connect()
      .then (update) =>
        servers = _.chain update.updates
          .where {serviceType: "discovery"}
          .pluck "serviceUri"
          .value()
        @serverList.addServers servers

  pingAllAnnouncements: () =>
    Promise.settle _.map(@_announcedRecords, @announce)
      .then Utils.groupPromiseInspections
      .then (resultGroups) =>
        if resultGroups.rejected.length > 0
          @logger.log "error", "#{resultGroups.rejected.length} announcements failed"
        resultGroups.fulfilled

  announce: (announcement) =>
    announcement.announcementId or= Utils.generateUUID()
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
    @_announcedRecords[announcement.announcementId] = announcement
    announcement

  unannounce: (announcement) ->
    @serverList.getRandom().then (server) =>
      url = "#{server}/announcement/#{announcement.announcementId}"
      request
        url: url
        method: "DELETE"
      .spread (response, body) =>
        delete @_announcedRecords[announcement.announcementId]
        @logger.log "info", "Unannounce DELETE '#{url}' " +
          "returned #{response.statusCode}:#{JSON.stringify(body)}"
      .catch (e) ->
        @serverList.dropServer server
        throw e

  startAnnouncementHeartbeat: () =>
    @stopAnnouncementHeartbeat()
    @_AnnouncementHeartbeatInterval = setInterval @pingAllAnnouncements, @HEARTBEAT_INTERVAL_MS

  stopAnnouncementHeartbeat: () =>
    if @_AnnouncementHeartbeatInterval
      clearInterval @_AnnouncementHeartbeatInterval
    @_AnnouncementHeartbeatInterval = null
