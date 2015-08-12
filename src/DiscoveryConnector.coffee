Promise= require "bluebird"
Errors = require "./Errors"
Utils = require "./Utils"
request = Promise.promisify require("request")

class DiscoveryConnector

  constructor: (@host, @serviceName, @logger) ->

  connectUrl: ()->
    "http://#{@host}/watch" +  if @serviceName?  then "?clientServiceType=#{@serviceName}" else ""

  connect: () ->
    url = @connectUrl()
    @logger.log("debug", "Attempting connection to #{url}")

    request
      url: url
      json: true
    .spread @handle

  handle: (response, body) =>
    if response.statusCode != 200
      throw new Errors.DiscoveryConnectError(body)

    update = body

    unless update?.fullUpdate
      throw new Errors.DiscoveryFullUpdateError(update)

    @logger.log 'debug', 'Discovery update: ' + JSON.stringify(update)

    return update

module.exports = DiscoveryConnector
