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
    # Utils.promiseRetry(@attemptConnect)
    @attemptConnect()


  attemptConnect:()=>
    RequestPromise(url:@connectUrl(), json:true)
      .then(@handle)
      .catch(@handleError)

  handleError:(error)=>
    @discoveryClient.notifyError(error)
    Promise.reject(error)

  handle:(response)->
    if response.statusCode != 200
      return Promise.reject(
        new Errors.DiscoveryConnectError(response.body))

    update = response.body

    unless update?.fullUpdate
      return Promise.reject(
        new Errors.DiscoveryFullUpdateError(update))

    #TODO: log debug statement
    return update

module.exports = DiscoveryConnector