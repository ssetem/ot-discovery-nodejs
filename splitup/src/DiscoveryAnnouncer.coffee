Promise = require "bluebird"
Errors = require "./Errors"
RequestPromise = require "./RequestPromise"
Utils = require "./Utils"
_ = require "lodash"

module.exports = class DiscoveryAnnouncer


  constructor:(@discoveryClient)->
    @announcements = {}
    @ANNOUNCE_ATTEMPTS = 20
    @INITIAL_BACKOFF = 500

  pingAllAnnouncements:()=>
    Promise.all(_.map(@announcements, @attemptAnnounce))
      .catch(@notifyAndReject)

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
    @server = @discoveryClient.serverList.getRandom()

    unless @server
      @discoveryClient.reconnect()
      return @notifyAndReject(new Error("Cannot announce. No discovery servers available"))

    @discoveryClient.log "debug", "Announcing " + JSON.stringify(announcement)
    url = @server + "/announcement"
    RequestPromise({
      url:url
      method:"POST"
      json:true
      body:announcement
    }).catch(@handleError).then(@handleResponse)


  handleError:(error)=>
    @discoveryClient.serverList.dropServer(@server)
    @notifyAndReject(error)

  handleResponse:(response)=>
    unless response?.statusCode is 201
      unless response.statusCode?
        @discoveryClient.serverList.dropServer(@server)
      return @notifyAndReject(new Error("During announce, bad status code #{response.statusCode}:#{JSON.stringify(response.body)}"))
    announcement = response.body
    @discoveryClient.log(
      "info", "Announced as " + JSON.stringify(announcement))
    @announcements[announcement.announcementId] = announcement
    return announcement

  unannounce:(announcement, callback)->
    @attemptUnannounce(announcement)
      .nodeify(callback)

  attemptUnannounce:(announcement)=>
    @server = @discoveryClient.serverList.getRandom()
    @removeAnnouncement(announcement)
    unless @server
      return @notifyAndReject(new Error("Cannot unannounce. No discovery servers available"))

    url = "#{@server}/announcement/#{announcement.announcementId}"
    RequestPromise({
      url:url
      method:"DELETE"
    }).then( (response)=>
      @discoveryClient.log("info", "Unannounce DELETE '#{url}' returned #{response.statusCode}:#{JSON.stringify(response.body)}")
    ).catch(@notifyAndReject)

  notifyAndReject:(error)=>
    @discoveryClient.notifyError(error)
    return Promise.reject(error)
