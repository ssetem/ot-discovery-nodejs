bluebird = require "bluebird"
Errors = require "./Errors"
RequestPromise = require "RequestPromise"
Utils = require "Utils"

class DiscoveryLongPoller


  constructor:(@discoveryClient)->

  schedulePoll:()=>
    if @discoveryClient.serverList.isEmpty()
      @discoveryClient.reconnect()
    else
      process.nextTick @poll

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
      @discoveryClient.notifyWatchers(response.body)
      @schedulePoll()
