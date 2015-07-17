DiscoveryClient = require "./DiscoveryClient"
_               = require "lodash"

class DiscoveryCLI

  @launch:()->
    requiredVars = [
      "TASK_HOST", "PORT0", "DISCOVERY_HOST", "SERVICE_TYPE"
    ]

    hasRequiredEnvVars = _.every _.map requiredVars, (envVar)->
      process.env[envVar]

    unless hasRequiredEnvVars
      throw new Error("DiscoveryCLI requires #{requiredVars.toString()} env vars.")


    host = process.env.TASK_HOST
    port = process.env.PORT0

    discoveryHost = process.env.DISCOVERY_HOST
    serviceType = process.env.SERVICE_TYPE

    client = new DiscoveryClient(discoveryHost)
    client.connect().then ()->
      client.announce({
        serviceType:serviceType
        serviceUri:"http://#{host}:#{port}"
      })


module.exports = DiscoveryCLI