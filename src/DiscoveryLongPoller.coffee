Promise        = require "bluebird"
Errors         = require "./Errors"
RequestPromise = require "./RequestPromise"
Utils          = require "./Utils"
request        = require "request"

class DiscoveryLongPoller

  constructor:(@serviceName, @serverList, @announcementIndex, @discoveryNotifier, @reconnect)->

  startPolling:()=>
    return if @shouldBePolling
    @shouldBePolling = true
    @schedulePoll()

  stopPolling:()->
    @shouldBePolling = false
    @currentRequest?.abort()

  schedulePoll:()=>
    return unless @shouldBePolling
    if @serverList.isEmpty()
      @reconnect()
    else
      @poll()

  poll:() =>
    @server = @serverList.getRandom()
    @nextIndex = @announcementIndex.index + 1
    url = "#{@server}/watch?since=#{@nextIndex}" + if @serviceName?  then "&clientServiceType=#{@serviceName}" else ""
    @currentRequest = request {url:url, json:true}, (error, response, body)=>
      if error
        @handleError error
      else
        @handleResponse response
      @schedulePoll()
      @currentRequest = null

  handleError:(error)=>
    return unless @shouldBePolling
    @serverList.dropServer(@server)
    @discoveryNotifier.notifyError(error)

  handleResponse:(response)=>
    return unless @shouldBePolling
    #no new updates
    unless response?.statusCode
      @handleError(new Error("Could not connect to #{@server}"))
    else if response.statusCode is 204
      return
    #bad status code
    else if response.statusCode isnt 200
      error = new Error("Bad status code " + response.statusCode + " from watch: " + response)
      @handleError(error)
    else
      @announcementIndex.processUpdate(response.body, true)


module.exports = DiscoveryLongPoller