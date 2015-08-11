Promise        = require "bluebird"
Errors         = require "./Errors"
Utils          = require "./Utils"
request = require "request"

class DiscoveryLongPoller
  constructor: (@serviceName, @serverList, @announcementIndex, @discoveryNotifier) ->

  startPolling: () =>
    return if @shouldBePolling
    @shouldBePolling = true
    @schedulePoll()

  stopPolling: () =>
    @shouldBePolling = false
    @currentRequest?.abort()

  schedulePoll: () =>
    return unless @shouldBePolling
    @poll().then @schedulePoll

  poll: () =>
    @serverList.getRandom()
      .then (server) =>
        @nextIndex = @announcementIndex.index + 1
        url = "#{server}/watch?since=#{@nextIndex}" + if @serviceName?  then "&clientServiceType=#{@serviceName}" else ""
        # we have to hand promisify here so we can grab the request object
        # for aborting purposes
        new Promise (resolve, reject) =>
          @currentRequest = request
            url:url
            json:true
          , (err, response, body) =>
            if err
              reject err
            else
              resolve [response, body]
        .spread @handleResponse
        .catch (error) =>
          @serverList.dropServer @server
          @discoveryNotifier.notifyError error
        .finally () =>
          @currentRequest = null

  handleResponse: (response, body) =>
    return unless @shouldBePolling
    #no new updates
    unless response?.statusCode
      throw new Error "Could not connect to #{response.request.url.http}"
    else if response.statusCode is 204
      return
    #bad status code
    else if response.statusCode isnt 200
      error = new Error "Bad status code " + response.statusCode + " from watch: " + response
      throw new Error error
    else
      @announcementIndex.processUpdate body
      @discoveryNotifier.notifyWatchers body

module.exports = DiscoveryLongPoller
