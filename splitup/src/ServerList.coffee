_ = require "lodash"



class ServerList

  constructor:(@discoveryClient)->
    @servers = []

  getRandom:()->
    _.sample(@servers)

  addServers:(servers=[])->
    @servers = _.uniq(@servers.concat servers)

  isEmpty:()->
    @servers.length is 0

  dropServer:(server)->
    @servers = _.without(@servers, server)



module.exports = ServerList