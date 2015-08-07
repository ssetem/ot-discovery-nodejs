Promise= require "bluebird"
Errors = require "./Errors"
Utils = require "./Utils"
request = Promise.promisify require("request")

class DiscoveryConnector

  constructor:(@host,@serviceName, @logger, @discoveryNotifier)->
    @CONNECT_ATTEMPTS = 100
    @INITIAL_BACKOFF = 500

  connectUrl:()->
    "http://#{@host}/watch" +  if @serviceName?  then "?clientServiceType=#{@serviceName}" else ""

  connect:()->
    Utils.promiseRetry(
      @attemptConnect
      @CONNECT_ATTEMPTS
      @INITIAL_BACKOFF
    )

  attemptConnect:()=>
    url = @connectUrl()
    @logger.log("debug", "Attempting connection to #{url}")

    request
      url: url
      json: true
    .catch @discoveryNotifier.notifyAndReject
    .spread @handle

  handle:(response, body)=>
    if response.statusCode != 200
      return @discoveryNotifier.notifyAndReject(
        new Errors.DiscoveryConnectError(body))

    update = body

    unless update?.fullUpdate
      return @discoveryNotifier.notifyAndReject(
        new Errors.DiscoveryFullUpdateError(update))

    @logger.log 'debug', 'Discovery update: ' + JSON.stringify(update)

    return update

module.exports = DiscoveryConnector
