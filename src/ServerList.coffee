_ = require "lodash"

class ServerList

  constructor:(@discoveryClient)->
    @servers = []

  getRandom:()->
    _.sample(@servers)

  addServers:(servers=[])->
    @discoveryClient.log('info', 'Syncing discovery servers ' + servers)
    @servers = _.uniq(@servers.concat servers)

  isEmpty:()->
    @servers.length is 0

  dropServer:(server)->
    @discoveryClient.log('info', 'Dropping discovery server ' + server)
    @servers = _.without(@servers, server)


module.exports = ServerList