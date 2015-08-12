_ = require "lodash"
Promise = require "bluebird"

class ServerList
  constructor: (@logger, @connect) ->
    @servers = []

  pickServer: () =>
    new Promise (resolve, reject) =>
      server = _.sample @servers

      if server
        resolve server
      else
        reject new Error("no servers left in rotation")

  getRandom: () ->
    @pickServer()
      .catch () =>
        @connect().then @pickServer

  addServers: (servers) ->
    @logger.log 'info', 'Syncing discovery servers ' + servers
    @servers = _.uniq @servers.concat(servers)

  isEmpty: () ->
    @servers.length is 0

  dropServer: (server) ->
    @logger.log 'info', 'Dropping discovery server ' + server
    @servers = _.without @servers, server


module.exports = ServerList
