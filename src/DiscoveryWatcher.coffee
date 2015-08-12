Promise = require "bluebird"
request = require "request"
url = require "url"

class DiscoveryWatcher
  constructor: () ->

  watch: (server, serviceName, index) =>
    query = {}
    query.since = index if index
    query.clientServiceType = serviceName if serviceName

    target = url.format
      protocol: 'http'
      host: server
      pathname: "watch"
      query: query

    # we have to hand promisify here so we can grab the request object
    # for aborting purposes
    new Promise (resolve, reject) =>
      @currentRequest = request
        url: target
        json: true
      , (err, response, body) ->
        if err
          reject err
        else
          resolve [response, body]
    .spread (response, body) =>
      @validateResponse response, body
    .finally () =>
      @currentRequest = null

  validateResponse: (response, body) ->
    #bad status code
    if response.statusCode in [200, 204]
      return body
    else
      error = new Error "Bad status code " + response.statusCode + " from watch: " + response
      throw error

module.exports = DiscoveryWatcher
