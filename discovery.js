var request = require("request");

/*
 * DiscoveryClient constructor.
 * Creates a new uninitialized DiscoveryClient.
 */
function DiscoveryClient(host, options) {
  this.host = host;
  this.state = {announcements: {}};
  this.errorHandlers = [this._backoff.bind(this)];
  this.watchers = [this._update.bind(this), this._unbackoff.bind(this)];
  this.announcements = [];
  this.backoff = 1;
  this.logger = (options && options.logger) || require("ot-logger");
}

/* Increase the watch backoff interval */
DiscoveryClient.prototype._backoff = function () {
  this.backoff = Math.min(this.backoff * 2, 10240);
};

/* Reset the watch backoff interval */
DiscoveryClient.prototype._unbackoff = function() {
  this.backoff = 1;
};

DiscoveryClient.prototype._randomServer = function() {
  return this.servers[Math.floor(Math.random()*this.servers.length)];
};

/* Consume a WatchResult from the discovery server and update internal state */
DiscoveryClient.prototype._update = function (update) {
  var disco = this;
  if (update.fullUpdate) {
    Object.keys(disco.state.announcements).forEach(function (id) { delete disco.state.announcements[id]; });
  }
  disco.state.index = update.index;
  update.deletes.forEach(function (id) { delete disco.state.announcements[id]; });
  update.updates.forEach(function (announcement) { disco.state.announcements[announcement.announcementId] = announcement; });
};

/* Connect to the Discovery servers given the endpoint of any one of them */
DiscoveryClient.prototype.connect = function (onComplete) {
  var disco = this;
  request({
    url: "http://" + this.host + "/watch",
    json: true
  }, function (error, response, update) {
    if (error) {
      onComplete(error);
      return;
    }
    if (response.statusCode != 200) {
      onComplete(new Error("Unable to initiate discovery: " + JSON.stringify(update)), undefined, undefined);
      return;
    }

    if (!update.fullUpdate) {
      onComplete(new Error("Expecting a full update: " + JSON.stringify(update)), undefined, undefined);
      return;
    }
    disco._update(update);

    disco.servers = [];

    Object.keys(disco.state.announcements).forEach(function (id) {
      var announcement = disco.state.announcements[id];
      if (announcement.serviceType == "discovery") {
        disco.servers.push(announcement.serviceUri);
      }
    });

    disco._schedule();
    setInterval(disco._announce.bind(disco), 10000);
    onComplete(undefined, disco.host, disco.servers);
  });
};

/* Register a callback on every discovery update */
DiscoveryClient.prototype.onUpdate = function (watcher) {
  this.watchers.push(watcher);
};

/* Register a callback on every error */
DiscoveryClient.prototype.onError = function (handler) {
  this.errorHandlers.push(handler);
};

/* Internal scheduling method.  Schedule the next poll in the event loop */
DiscoveryClient.prototype._schedule = function() {
  var c = this.poll.bind(this);
  if (this.backoff <= 1) {
    setImmediate(c);
  } else {
    setTimeout(c, this.backoff).unref();
  }
};

/* Long-poll the discovery server for changes */
DiscoveryClient.prototype.poll = function () {
  var disco = this;
  var server = this._randomServer();
  var url = server + "/watch?since=" + (this.state.index + 1);
  request({
    url: url,
    json: true
  }, function (error, response, body) {
    if (error) {
      disco.errorHandlers.forEach(function (h) { h(error); });
      disco._schedule();
      return;
    }
    if (response.statusCode == 204) {
      disco._schedule();
      return;
    }
    if (response.statusCode != 200) {
      var err = new Error("Bad status code " + response.statusCode + " from watch: " + response);
      disco.errorHandlers.forEach(function (h) { h(err); });
      disco._schedule();
      return;
    }
    disco.watchers.forEach(function (w) { w(body); });
    disco._schedule();
  });
};

/* Lookup a service by service type!
 * Accepts one of:
 *   serviceType as string
 *   serviceType:feature as string
 *   predicate function over announcement object
 */
DiscoveryClient.prototype.findAll = function (predicate) {
  var disco = this;
  var candidates = [];

  if (typeof(predicate) != "function") {
    var serviceType = predicate;
    predicate = function(a) {
      return a.serviceType == serviceType || a.serviceType + ":" + a.feature == serviceType;
    };
  }

  Object.keys(disco.state.announcements).forEach(function (id) {
    var a = disco.state.announcements[id];
    if (predicate(a)) {
      candidates.push(a.serviceUri);
    }
  });

  return candidates;
};

DiscoveryClient.prototype.find = function (predicate) {
  var candidates = this.findAll(predicate);
  if (candidates.length === 0) {
    return undefined;
  }
  return candidates[Math.floor(Math.random()*candidates.length)];
};

DiscoveryClient.prototype._announce = function() {
  var disco = this;
  function cb(error, announcement) {
    if (error) {
      disco.errorHandlers.forEach(function (h) { h(error); });
    }
  }
  this.announcements.forEach(function (a) {
    disco._singleAnnounce(a, cb);
  });
};

DiscoveryClient.prototype._singleAnnounce = function (announcement, cb) {
  var server = this._randomServer();
  request({
    url: server + "/announcement",
    method: "POST",
    json: true,
    body: announcement
  }, function (error, response, body) {
    if (error) {
      cb(error);
      return;
    }
    if (response.statusCode != 201) {
      cb(new Error("During announce, bad status code " + response.statusCode + ": " + JSON.stringify(body)));
      return;
    }
    cb(undefined, body);
  });
};

/* Announce ourselves to the registry */
DiscoveryClient.prototype.announce = function (announcement, cb) {
  var disco = this;
  this._singleAnnounce(announcement, function(error, a) {
    if (error) {
      cb(error);
      return;
    }
    disco.logger.log("Announced as " + a.serviceType);
    disco.announcements.push(a);
    cb(undefined, a);
  });
};

/* Remove a previous announcement.  The passed object *must* be the
 * lease as returned by the 'announce' callback. */
DiscoveryClient.prototype.unannounce = function (announcement, callback) {
  var disco = this;
  var server = disco._randomServer();
  var url = server + "/announcement/" + announcement.announcementId;
  disco.announcements.splice(disco.announcements.indexOf(announcement), 1);
  request({
    url: url,
    method: "DELETE"
  }, function (error, response, body) {
    if (error) {
      disco.logger.error(error);
    } else {
      disco.logger.log("Unannounce DELETE '" + url + "' returned " + response.statusCode + ": " + JSON.stringify(body));
    }
    if (callback) {
      callback();
    }
  });
};

module.exports = DiscoveryClient;
