request   = require "request"
bluebird  = require "bluebird"


module.exports = (config)-> new bluebird (resolve, reject)->
  request config, (error, response, body)->
    if error then return reject error
    resolve(response)


