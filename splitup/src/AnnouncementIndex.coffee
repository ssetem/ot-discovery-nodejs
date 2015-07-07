_ = require "lodash"


class AnnouncementIndex


  constructor:(@discoveryClient)->
    @announcements = {}
    @discoveryServers = []
    @index = -1


  processUpdate:(update)->
    if update.fullUpdate
      @clearAnnouncements()

    @setIndex(update.index)
    @removeAnnouncements(update.deletes)
    @addAnnouncements(update.updates)
    @computeDiscoveryServers()
    @discoveryClient.notifyWatchers(update)

  removeAnnouncements:(ids=[])->
    @announcements = _.omit(@announcements, ids)


  addAnnouncements:(announcements=[])->
    @announcements = _.extend(
      @announcements
      _.indexBy(announcements, "announcementId")
    )

  clearAnnouncements:()->
    @announcements = {}

  setIndex:(@index)=>

  computeDiscoveryServers:()->
    @discoveryServers = _.chain(@announcements)
      .where({serviceType:"discovery"})
      .pluck("serviceUri")
      .value()
    @discoveryClient.serverList.addServers(@discoveryServers)

  getDiscoveryServers:()->
    @discoveryServers


  serviceTypePredicate:(serviceType)-> (announcement)->
    serviceType in [
      announcement.serviceType
      "#{announcement.serviceType}:#{announcement.feature}"
    ]

  findAll:(predicate)->
    unless _.isFunction(predicate)
      predicate = @serviceTypePredicate(predicate)

    _.filter(@announcements, predicate)

  find:(predicate)->
    _.sample @findAll(predicate)


module.exports = AnnouncementIndex