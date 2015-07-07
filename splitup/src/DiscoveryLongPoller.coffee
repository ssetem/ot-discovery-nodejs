Promise = require "bluebird"
Errors = require "./Errors"
RequestPromise = require "./RequestPromise"
Utils = require "./Utils"

class DiscoveryLongPoller


  constructor:(@discoveryClient)->

  startPolling:()=>
    return if @shouldBePolling
    @shouldBePolling = true
    @schedulePoll()

  schedulePoll:()=>
    return unless @shouldBePolling
    if @discoveryClient.serverList.isEmpty()
      @discoveryClient.reconnect()
    else
      @poll()

  poll:()=>
    @server = @discoveryClient.serverList.getRandom()
    @nextIndex = @discoveryClient.announcementIndex.index + 1
    url = "http://#{@server}/watch?since=#{@nextIndex}"
    RequestPromise(url:url, json:true)
      .catch(@handleError)
      .then(@handleResponse)

  handleError:(error)=>
    @discoveryClient.notifyError(error)
    @discoveryClient.serverList.dropServer(@server)
    @schedulePoll()

  handleResponse:(response)=>
    #no new updates
    if response.statusCode is 204
      @schedulePoll()
    #bad status code
    else if response.statusCode isnt 200
      error = new Error("Bad status code " + response.statusCode + " from watch: " + response)
      @discoveryClient.notifyError(error)
      @discoveryClient.serverList.dropServer(@server)
      @schedulePoll()
    else
      @discoveryClient.announcementIndex.processUpdate(response.body)
      @schedulePoll()

module.exports = DiscoveryLongPoller