http = require 'http'
dispatch = require 'dispatch'
quip = require 'quip'
_ = require 'lodash'

WATCH_DELAY = 100
WATCH_INDEX_DELAY = 300


class DiscoveryAnnouncer
  constructor: () ->
    @_state = []
    @_index = 1
    @setDefaultAnnouncement()

  setDefaultAnnouncement: () ->
    @_state = @_state.concat [
      announcementId:"disco"
      serviceType : "discovery"
      serviceUri  : 'http://localhost:9001'
    ,
      announcementId:"other"
      serviceType : "other"
      serviceUri  : "foobar"
    ]

  getAnnouncements: () ->
    return @_state

  getWatchReply: () =>
    ret =
      fullUpdate: true
      updates: @getAnnouncements()
      index: @_index
      deletes: []

  addAnnouncement: (announcement) ->
    @_index += 1
    @_state.push announcement

  removeAnnouncement: (id) ->
    _.remove @_state, (announcement) ->
      if announcement.announcementId == id
        return true
      return false


_announcer = new DiscoveryAnnouncer()

class DiscoveryIntegrationTestServer

  start: (port, cb) =>
    @_server = http.createServer dispatch(
      '/watch' : (req, res) ->
        setTimeout () ->
          quip(res).ok _announcer.getWatchReply()
        , WATCH_DELAY

      'POST /announcement': (req, res, next, post) ->
        data = ""

        req.on 'data', (chunk) ->
          data += chunk

        req.on 'end', () ->
          _announcer.addAnnouncement JSON.parse(data)
          quip(res).created data

      'DELETE /announcement/:id': (req, res, id) ->
        _announcer.removeAnnouncement id
        quip(res).ok "SUCCESS"
      )
    @_server.listen port, (err, x) ->
      cb(err, x)

  end: (cb) =>
    @_server.close cb
    _announcer = new DiscoveryAnnouncer()

  logger: (url, endpoint, returnedstatuscode, message) =>
    unless @logs
      @logs = []
    @logs.push "#{url},#{endpoint}, #{returnedstatuscode}, #message"
    #console['log'] "do stuff"

module.exports = DiscoveryIntegrationTestServer