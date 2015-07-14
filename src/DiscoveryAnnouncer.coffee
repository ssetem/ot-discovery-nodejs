Promise        = require "bluebird"
Errors         = require "./Errors"
RequestPromise = require "./RequestPromise"
Utils          = require "./Utils"
_              = require "lodash"

module.exports = class DiscoveryAnnouncer

  constructor:(@logger, @serverList, @discoveryNotifier, @reconnect)->
    @announcements = {}
    @ANNOUNCE_ATTEMPTS = 20
    @INITIAL_BACKOFF = 500

  pingAllAnnouncements:()=>
    Promise.settle(_.map(@announcements, @attemptAnnounce))
      .then(Utils.groupPromiseInspections)
      .then (resultGroups)=>
        if resultGroups.rejected?.length > 0
          @logger.log "error", "#{resultGroups.rejected?.length} announcements failed"
        resultGroups.fulfilled

  announce:(announcement, callback)->
    Utils.promiseRetry(
      @attemptAnnounce.bind(@, announcement)
      @ANNOUNCE_ATTEMPTS
      @INITIAL_BACKOFF
    ).nodeify(callback)

  removeAnnouncement:(announcement)->
    delete @announcements[announcement.announcementId]

  attemptAnnounce:(announcement)=>
    announcement.announcementId or= Utils.generateUUID()
    @server = @serverList.getRandom()

    unless @server
      @reconnect()
      return @discoveryNotifier.notifyAndReject(
        new Error("Cannot announce. No discovery servers available"))

    @logger.log "debug", "Announcing " + JSON.stringify(announcement)
    url = @server + "/announcement"
    RequestPromise({
      url:url
      method:"POST"
      json:true
      body:announcement
    }).catch(@handleError).then(@handleResponse)


  handleError:(error)=>
    @serverList.dropServer(@server)
    @discoveryNotifier.notifyAndReject(error)

  handleResponse:(response)=>
    unless response?.statusCode is 201
      return @discoveryNotifier.notifyAndReject(
        new Error("During announce, bad status code #{response.statusCode}:#{JSON.stringify(response.body)}"))
    announcement = response.body
    @logger.log(
      "info", "Announced as " + JSON.stringify(announcement))
    @announcements[announcement.announcementId] = announcement
    return announcement

  unannounce:(announcement, callback)->
    @attemptUnannounce(announcement)
      .nodeify(callback)

  attemptUnannounce:(announcement)=>
    @server = @serverList.getRandom()
    @removeAnnouncement(announcement)
    unless @server
      return @discoveryNotifier.notifyAndReject(
        new Error("Cannot unannounce. No discovery servers available"))

    url = "#{@server}/announcement/#{announcement.announcementId}"
    RequestPromise({
      url:url
      method:"DELETE"
    }).then( (response)=>
      @logger.log("info", "Unannounce DELETE '#{url}' returned #{response.statusCode}:#{JSON.stringify(response.body)}")
    ).catch(@discoveryNotifier.notifyAndReject)

