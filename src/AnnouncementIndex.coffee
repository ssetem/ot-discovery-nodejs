_ = require "lodash"


class AnnouncementIndex

  constructor:(@serverList, @discoveryNotifier)->
    @announcements = {}
    @discoveryServers = []
    @index = -1

  processUpdate:(update, shouldNotify)->
    if update.fullUpdate
      @clearAnnouncements()

    @setIndex(update.index)
    @removeAnnouncements(update.deletes)
    @addAnnouncements(update.updates)
    @computeDiscoveryServers()
    if shouldNotify
      @discoveryNotifier.notifyWatchers(update)

  removeAnnouncements:(ids=[])->
    @announcements = _.omit(@announcements, ids)

  addAnnouncements:(announcements=[])->
    @announcements = _.extend(
      @announcements,
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
    @serverList.addServers(@discoveryServers)

  getDiscoveryServers:()->
    @discoveryServers

  serviceTypePredicate:(serviceType, announcement)->
    serviceType in [
      announcement.serviceType
      "#{announcement.serviceType}:#{announcement.feature}"
    ]

  findAll:(predicate)->
    unless _.isFunction(predicate)
      predicate = @serviceTypePredicate.bind(@, predicate)

    _.chain(@announcements)
      .filter(predicate)
      .pluck("serviceUri")
      .value()

  find:(predicate)->
    _.sample @findAll(predicate)


module.exports = AnnouncementIndex