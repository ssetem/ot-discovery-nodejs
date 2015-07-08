Promise = require "bluebird"
Errors = require "./Errors"
RequestPromise = require "./RequestPromise"
Utils = require "./Utils"
uuid = require "node-uuid"
_ = require "lodash"

module.exports = class DiscoveryAnnouncer


  constructor:(@discoveryClient)->
    @announcements = []
    @ANNOUNCE_ATTEMPTS = 20

  pingAllAnnouncements:()=>
    Promise.all(_.map(
      @announcements, @attemptAnnounce
    )).catch (error)=>
      @discoveryClient.notifyError(error)
      Promise.reject(error)

  announce:(announcement, callback)->
    Utils.promiseRetry(=>
      @attemptAnnounce(announcement)
    ,@ANNOUNCE_ATTEMPTS).nodeify(callback)


  removeAnnouncement:(announcement)->
    @announcements = _.without(@announcements, announcement)

  unannounce:(announcement, callback)->
    @attemptUnannounce(announcement)
      .nodeify(callback)

  attemptUnannounce:(announcement)=>
    @server = @discoveryClient.serverList.getRandom()
    @removeAnnouncement(announcement)
    unless @server
      errorMessage = 'Cannot unannounce. No discovery servers available'
      @discoveryClient.log "info", errorMessage
      return Promise.reject(new Error(errorMessage))

    RequestPromise({
      url:"#{@server}/announcement/#{announcement.announcementId}"
      method:"DELETE"
    }).then( (response)=>
      @discoveryClient.log("info", "Unannounce DELETE '" + url + "' returned " + response.statusCode + ": " + JSON.stringify(response.body))
    ).catch((error)=>
      @discoveryClient.notifyError(error)
    )

  attemptAnnounce:(announcement)=>
    announcement.announcementId or= uuid.v4()
    @server = @discoveryClient.serverList.getRandom()

    unless @server
      errorMessage = 'Cannot announce. No discovery servers available'
      @discoveryClient.log "info", errorMessage
      @discoveryClient.reconnect()
      return Promise.reject(new Error(errorMessage))

    @discoveryClient.log "debug", "Announcing " + JSON.stringify(announcement)
    url = @server + "/announcement"
    console.log url
    RequestPromise({
      url:url
      method:"POST"
      json:true
      body:announcement
    }).then(@handleResponse).catch(@handleError)


  handleError:(error)=>
    @discoveryClient.serverList.dropServer(@server)
    Promise.reject(error)

  handleResponse:(response)=>
    unless response.statusCode is 201
      return Promise.reject(new Error(
        "During announce, bad status code #{response.statusCode}:#{JSON.stringify(response.body)}"))
    announcement = response.body
    @discoveryClient.log(
      "info", "Announced as " + JSON.stringify(announcement))
    @announcements.push(announcement)
    return announcement

