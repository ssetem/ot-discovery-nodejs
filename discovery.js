var request = require("request");

/*
 * DiscoveryClient constructor.
 * Creates a new uninitialized DiscoveryClient.
 */
function DiscoveryClient(host) {
  this.host = host;
  this.state = {announcements: {}};
  this.errorHandlers = [this._backoff.bind(this)];
  this.watchers = [this._update.bind(this), this._unbackoff.bind(this)];
  this.announcements = [];
  this.backoff = 1;
}

/* Increase the watch backoff interval */
DiscoveryClient.prototype._backoff = function () {
  this.backoff = Math.min(this.backoff * 2, 10240);
}

/* Reset the watch backoff interval */
DiscoveryClient.prototype._unbackoff = function() {
  this.backoff = 1;
}

DiscoveryClient.prototype._randomServer = function() {
  return this.servers[Math.floor(Math.random()*this.servers.length)];
}

/* Consume a WatchResult from the discovery server and update internal state */
DiscoveryClient.prototype._update = function (update) {
  var disco = this;
  if (update.fullUpdate) {
    Object.keys(disco.state.announcements).forEach(function (id) { delete disco.state.announcements[id]; });
  }
  disco.state.index = update.index;
  update.deletes.forEach(function (id) { delete disco.state.announcements[id]; });
  update.updates.forEach(function (announcement) { disco.state.announcements[announcement.announcementId] = announcement; });
}

/* Connect to the Discovery servers given the endpoint of any one of them */
DiscoveryClient.prototype.connect = function (onComplete) {
  var disco = this;
  request("http://" + this.host + "/watch", function (error, response, body) {
    if (error) {
      onComplete("Unable to initiate discovery: " + error, undefined, undefined);
    }
    if (response.statusCode != 200) {
      onComplete("Unable to initiate discovery: " + body, undefined, undefined);
    }
    var update = JSON.parse(body);
    if (!update.fullUpdate) {
      onComplete("Expecting a full update: " + update, undefined, undefined);
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
}

/* Register a callback on every error */
DiscoveryClient.prototype.onError = function (handler) {
  this.errorHandlers.push(handler);
}

/* Internal scheduling method.  Schedule the next poll in the event loop */
DiscoveryClient.prototype._schedule = function() {
  var c = this.poll.bind(this);
  if (this.backoff <= 1) {
    setImmediate(c);
  } else {
    setTimeout(c, this.backoff).unref();
  }
}

/* Long-poll the discovery server for changes */
DiscoveryClient.prototype.poll = function () {
  var disco = this;
  var server = this._randomServer();
  var url = server + "/watch?since=" + (this.state.index + 1);
  request(url, function (error, response, body) {
    if (error) {
      var errorMsg = "Unable to watch discovery: " + error;
      disco.errorHandlers.forEach(function (h) { h(errorMsg); });
      disco._schedule();
      return;
    }
    if (response.statusCode == 204) {
      disco._schedule();
      return;
    }
    if (response.statusCode != 200) {
      var error = "Bad status code " + response.statusCode + " from watch: " + response;
      disco.errorHandlers.forEach(function (h) { h(error); });
      disco._schedule();
      return;
    }
    var response = JSON.parse(body);
    disco.watchers.forEach(function (w) { w(response); });
    disco._schedule();
  });
};

/* Lookup a service by service type! */
DiscoveryClient.prototype.find = function (serviceType) {
  var disco = this;
  var candidates = [];
  Object.keys(disco.state.announcements).forEach(function (id) {
    var a = disco.state.announcements[id];
    if (a.serviceType == serviceType) {
      candidates.push(a.serviceUri);
    }
  });
  if (candidates.length == 0) {
    return undefined;
  }
  return candidates[Math.floor(Math.random()*candidates.length)];
}

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
}

DiscoveryClient.prototype._singleAnnounce = function (announcement, cb) {
  var server = this._randomServer();
  request({
    url: server + "/announcement",
    method: "POST",
    headers: {
      "Content-Type": "application/json"
    },
    body: JSON.stringify(announcement)
  }, function (error, response, body) {
    if (error) {
      var errorMsg = "Unable to announce: " + error;
      cb(errorMsg);
      return;
    }
    if (response.statusCode != 201) {
      var errorMsg = "During announce, bad status code " + response.statusCode + ": " + body;
      cb(errorMsg);
      return;
    }
    cb(undefined, JSON.parse(body));
  });
}

/* Announce ourselves to the registry */
DiscoveryClient.prototype.announce = function (announcement, cb) {
  var disco = this;
  this._singleAnnounce(announcement, function(error, a) {
    if (error) {
      cb(error);
      return;
    }
    disco.announcements.push(a);
    cb(undefined, a);
  });
}

/* Remove a previous announcement */
DiscoveryClient.prototype.unannounce = function (announcement) {
  var server = this._randomServer();
  var url = server + "/announcement/" + announcement.announcementId;
  this.announcements.splice(this.announcements.indexOf(announcement), 1);
  request({
    url: url,
    method: "DELETE"
  }, function (error, response, body) {
    if (error) {
      console.error(error);
      return;
    }
    console.log("Unannounce DELETE '" + url + "' returned " + response.statusCode + ": " + body);
  });
}

exports.DiscoveryClient = DiscoveryClient;
