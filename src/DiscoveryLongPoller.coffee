Promise        = require "bluebird"
Errors         = require "./Errors"
RequestPromise = require "./RequestPromise"
Utils          = require "./Utils"
request        = require "request"

class DiscoveryLongPoller

  constructor:(@discoveryClient)->

  startPolling:()=>
    return if @shouldBePolling
    @shouldBePolling = true
    @schedulePoll()

  stopPolling:()->
    @shouldBePolling = false
    if @_currentRequest then @_currentRequest.abort()

  schedulePoll:()=>
    return unless @shouldBePolling
    if @discoveryClient.serverList.isEmpty()
      @discoveryClient.reconnect()
    else
      @poll()

  poll:()=>
    @server = @discoveryClient.serverList.getRandom()
    @nextIndex = @discoveryClient.announcementIndex.index + 1
    url = "#{@server}/watch?since=#{@nextIndex}"
    @_currentRequest = request {url:url, json:true}, (error, response, body)=>
      if error
        @handleError(error)
      else
        @handleResponse response
      @_currentRequest = null

  handleError:(error)=>
    return unless @shouldBePolling
    @discoveryClient.serverList.dropServer(@server)
    @discoveryClient.notifyError(error)
    @schedulePoll()

  handleResponse:(response)=>
    return unless @shouldBePolling
    #no new updates
    unless response?.statusCode
      @handleError(new Error("Could not connect to #{@server}"))
    else if response.statusCode is 204
      @schedulePoll()
    #bad status code
    else if response.statusCode isnt 200
      error = new Error("Bad status code " + response.statusCode + " from watch: " + response)
      @discoveryClient.serverList.dropServer(@server)
      @discoveryClient.notifyError(error)
      @schedulePoll()
    else
      @discoveryClient.announcementIndex.processUpdate(response.body, true)
      @schedulePoll()

module.exports = DiscoveryLongPoller