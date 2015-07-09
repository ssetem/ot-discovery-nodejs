Promise = require "bluebird"
Errors = require "./Errors"
RequestPromise = require "./RequestPromise"
Utils = require "./Utils"

class DiscoveryConnector


  constructor:(@discoveryClient)->
    @host = @discoveryClient.host

  connectUrl:()->
    "http://#{@host}/watch"

  connect:()->
    Utils.promiseRetry(@attemptConnect)

  attemptConnect:()=>
    url = @connectUrl()
    @discoveryClient.log("debug", "Attempting connection to #{url}")

    RequestPromise(url:url, json:true)
      .then(@handle)
      .catch(@discoveryClient.notifyAndReject)

  handle:(response)=>
    if response.statusCode != 200
      return @discoveryClient.notifyAndReject(
        new Errors.DiscoveryConnectError(response.body))

    update = response.body

    unless update?.fullUpdate
      return @discoveryClient.notifyAndReject(
        new Errors.DiscoveryFullUpdateError(update))

    @discoveryClient.log 'debug', 'Discovery update: ' + JSON.stringify(update)

    #TODO: log debug statement
    return update

module.exports = DiscoveryConnector