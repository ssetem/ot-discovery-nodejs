bluebird = require "bluebird"
Errors = require "./Errors"
RequestPromise = require "RequestPromise"
Utils = require "Utils"

class DiscoveryConnector


  constructor:(@discoveryClient)->
    @host = @discoveryClient.host

  connectUrl:()->
    "http://#{@host}/watch"

  connect:()->
    Utils.promiseRetry @attemptConnect

  attemptConnect:()=>
    RequestPromise(url:@connectUrl(), json:true)
      .then(@handle)

  handle:(response)->
    if response.statusCode != 200
      return bluebird.reject(new Errors.DiscoveryError(response.body))

    update = response.body

    unless update?.fullUpdate
      return bluebird.reject(
        new Errors.DiscoveryFullUpdateError(update))

    #TODO: log debug statement
    return update
