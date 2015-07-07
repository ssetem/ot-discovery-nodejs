Promise = require "bluebird"
Errors = require "./Errors"
RequestPromise = require "RequestPromise"
Utils = require "Utils"
uuid = require "uuid"
_ = require "lodash"

class DiscoveryAnnouncer


  constructor:(@discoveryClient)->

    @announcements = []

  pingAllAnnouncements:()->
    Promise.all(_.map(
      @announcements, @attemptAnnounce
    )).catch (error)=>
      @discoveryClient.notifyError(error)
      Promise.reject(error)

  announce:(annoucement, callback)->
    Utils.promiseRetry =>
      @attemptAnnounce(announcement)

  removeAnnouncement:(announcement)->
    @announcements = _.without(@announcements, announcement)

  unannounce:(announcement, callback)->
    @attemptUnannounce(announcement)
      .nodeify(callback)

  attemptUnannounce:(announcement)->
    @server = @discoveryClient.serverList.getRandom()
    @removeAnnouncement(announcement)
    unless @server
      errorMessage = 'Cannot unannounce. No discovery servers available'
      @discoveryClient.log "info", errorMessage
      return Promise.reject(new Error(errorMessage))

    #TODO adding logging
    RequestPromise({
      url:"#{@server}/announcement/#{announcement.announcementId}"
      method:"DELETE"
    })

  attemptAnnounce:(announcement)->
    announcement.announcementId or= uuid.v4()
    @server = @discoveryClient.serverList.getRandom()

    unless server
      errorMessage = 'Cannot announce. No discovery servers available'
      @discoveryClient.log "info", errorMessage
      @discoveryClient.reconnect()
      return Promise.reject(new Error(errorMessage))

    @discoveryClient.log "debug". "Announcing " + JSON.stringify(announcement)

    RequestPromise({
      url:server + "/announcement"
      method:"POST"
      json:true
      body:announcement
    }).catch(@handleError).then(@handleResponse)


  handleError:(error)->
    @discoveryClient.serverList.dropServer(@server)
    Promise.reject(error)

  handleResponse:(response)=>
    unless response.statusCode is 201
      return Promise.reject(new Error(
        "During announce, bad status code #{response.statusCode}:#{JSON.stringify(body)}"))
    announcement = response.body
    @announcements.push(announcement)
    return announcement