Promise        = require "bluebird"
Errors         = require "./Errors"
RequestPromise = require "./RequestPromise"
Utils          = require "./Utils"

class DiscoveryConnector

  constructor:(@discoveryClient)->
    @host = @discoveryClient.host
    @CONNECT_ATTEMPTS = 100
    @INITIAL_BACKOFF = 500

  connectUrl:()->
    "http://#{@host}/watch"

  connect:()->
    Utils.promiseRetry(
      @attemptConnect
      @CONNECT_ATTEMPTS
      @INITIAL_BACKOFF
    )

  attemptConnect:()=>
    url = @connectUrl()
    @discoveryClient.log("debug", "Attempting connection to #{url}")

    RequestPromise(url:url, json:true)
      .catch(@discoveryClient.notifyAndReject)
      .then(@handle)

  handle:(response)=>
    if response.statusCode != 200
      return @discoveryClient.notifyAndReject(
        new Errors.DiscoveryConnectError(response.body))

    update = response.body

    unless update?.fullUpdate
      return @discoveryClient.notifyAndReject(
        new Errors.DiscoveryFullUpdateError(update))

    @discoveryClient.log 'debug', 'Discovery update: ' + JSON.stringify(update)

    return update

module.exports = DiscoveryConnector