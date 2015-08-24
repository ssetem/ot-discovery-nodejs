# OT Discovery Client
[![Build Status](https://travis-ci.org/opentable/ot-discovery-nodejs.png?branch=master)](https://travis-ci.org/opentable/ot-discovery-nodejs) [![NPM version](https://badge.fury.io/js/ot-discovery.png)](http://badge.fury.io/js/ot-discovery) ![Dependencies](https://david-dm.org/opentable/ot-discovery-nodejs.png)

Client for OT flavoured service discovery

```
npm install ot-discovery --save
```

### Discovery

#### Introduction

Discovery is the process in which services are -- well -- *discovered*. In general, static file based configuration lacks flexibility, and well-known named load balancers lack distributed and highly reliable behavior. Before using the disco client, understand the behavior and architecture, otherwise it is likely you will lose or otherwise drop services (invariably during production and on a highly critical service).

#### Architecture

There are multiple *discovery regions*. Each discovery region is represented by a well-known server name, such as `discovery-sc.otenv.com`.
A region maps more or less to a network/physical machine region. For example, we have `discovery-sc`, `discovery-ln`, `discovery-uswest2`, and so on.
In general, the services that announce in a region are co-located closely both in network terms and physical terms; but services may and can announce in any region they wish, including regions far away from them.

Discovery regions are hosted on multiple *discovery servers*. Together, these form a redundant set of servers that enable robustness. Each are identical and any can respond to API calls. The well-known region name, such as `discovery-sc.otenv.com`, simply points to one of these, so the client can get the actual list of *discovery servers*.

A service can *announce*. This means that the *discovery region* will contain a record of that service -- it's name and the URI at which it can be found. By design, a service can -- and probably should -- announce multiple servers with the same service name. In that case, the client will **randomly** pick one server every time that service name is requested.

**Once a service has begun announcing, it must re-announce frequently**. If it does not re-announce within 10 seconds, the service will be **forcibly** removed by discovery.

A service can also *unannounce*. This means what it says on the tin -- the record will be removed immediately, and no longer be *discoverable*.

#### Watching

*"Watching"* is the process of getting a local cache of the discovery records. Then, whenever a client `find`s, the disco-client returns a valid URI for a service sychronously and without network traffic. *Watching* occurs via a long-poll of one of the discovery servers. Discovery clients can watch in one region only, by design.

When `find`ing, disco-client prefers the records that are in the *discovery region*. If there are none, but there are records for another region, then it will fall back to those. For example, imagine that we are discovering in `discovery-sc`, and that `serviceA` has two records in `discovery-sc`: one that is in the `discovery-sc` region, and one that is in the `uswest-2` region. disco-client will prefer to return the `discovery-sc` one, until it disappears (perhaps the server went down). At that point, it will pick "any other fallback" - this might be one in `uswest-2`, or even potentially another region.

#### Announcing & unannouncing

To *announce*, describe the `serviceType` and the `serviceUri`. Note that the `serviceUri` can be anything that resolves; e.g. IP address, FQDN, etc. The disco-client returns an *lease* object, an *opaque* object that describes the announcement, so that later, the service can unannounce if it wishes to do so.

Once a service *announces*, discovery servers will ping the URI with `OPTION '/'`. The service must reply success (any HTTP success code). Otherwise the *announcement* will **fail**. 

Once *announced*, the service must continually reannounce. The disco-client reannounces every 10 seconds.

It is possible and indeed sometimes necessary to announce in multiple regions. When announcing in multiple regions, describe the `homeRegion`. This is the name of the region the server is physically hosted in. For example, it is possible to announce in the `prod-sc` region that a service is available, but hosted in `prod-uswest2`. 

#### Good design practices

There are several complications with robustly announcing and discovering services.

##### Handling announcements and unannouncements as part of deployment
It is likely that most services are HTTP servers. Consider providing a HTTP endpoint that announces and unannounces the server.

`express-service-discovery` middleware does this if you are using express.

Then, only POST to that endpoint once your smoke tests indicate the server is fully up and ready to receive requests.

Be careful to install your endpoint as early as possible. If your server is half up and half down, it may not respond to the HTTP request to take itself down.

##### Handling announcement and unannouncement failures
Recall that announcement happens every 10 seconds. If your announcement fails, do not call `announce` again: it will be retried in 10 seconds.
The announcement callback will fail if **any** of the regions fail to announce.

If unannouncement fails, retry until it succeeds. `unannounce` does nothing if disco-client knows the announcement is already gone.
The unannouncement callback will fail if **any** of the regions fail to unannounce.

##### Announcement and watching are separate
You do not need to wait for `connect` to succeed before calling `announce`. `Announce` could announce to regions that don't even include your discovery region.
If some connection issue occurs for `connect` or during *watching*, it does not affect *announcing*, and vice versa.

##### Handling watching and connecting failures
Connect does not retry. If connect fails, do not continue spinning your server up. Reattempt as often as you wish, but as a polite citizen, consider using an exponential backoff.

If during *watching*, a long poll fails, disco-client will **fail-over** to another disco server in that region. There does not need to be an action taken by you. If all the disco servers fail-over, then disco-client will attempt to reconnect to the original well-known name to find new servers. That would be, for example, `discovery-sc.otenv.com`. If this fails, the disco client will retry 10 times, with exponential backoff, until it succeeds. If even this fails, a error will be notified, but the disco client will continue to retry, and every 10 failures to connect to the well-known disco-server, a error will be notified.

In general, `disco.find` calls will continue to work during the reconnect / fail-over process: recall that disco-client maintains a **local cache** of all records. However, ultimately they will become stale.

Consider adding production logging or alerting when these errors are logged, and implementing a strategy for removing the server from disco if it has been disco-stale for 'too long'.

### Quick usage

``` javascript
var discovery = require("ot-discovery");
var disco = new discovery('discovery-sc.otenv.com',
  ['discovery-sc.otenv.com', 'discovery-uswest2.otenv.com'],
  'prod-sc', 'myServiceName', { /* options */});

disco.connect(function(err) {
  if(err) {
    //please retry
    return;
  }

  url = disco.find('foobar-service') + '/foobar-service-api';
});

disco.announce({
  serviceType: 'myServiceName',
  serviceUri: 'myHost'
}, function(err, lease) {
  if(err) {
    //log, but do not retry; perhaps wait before continuing
    //to spin up the server
    return;
  }

  //some time later
  disco.unannounce(lease, function(err) {
    if(err) {
      //please retry
    }

    //we now are unannounced. restart the server, perhaps
  });
});

```

### API documentation

#### constructor
```
DiscoveryClient(discoveryHost, announcementHosts, homeRegionName, serviceName, options)
```

`discoveryHost`: the well-known name of the discovery region

`announcementHosts`: an array of well-known names for announcing in

`homeRegionName`: the name of the region that the service will be hosted in. This is **not** `discovery-sc.otenv.com`, but one of the following: `ci-sf`, `pp-sf`, `pp-uswest2`, `prod-sc`, `prod-uswest2`, `prod-ln` or `prod-euwest1`.

`serviceName`: the name of the service that is discovering in the discovery region. This does **not** have to be the same name as the name of the service that might be announced, but in general, is likely to be.

`options`: optional.

`options.logger`: a logger that conforms to `ot-logger`.

```
DiscoveryClient(host, options)
```

`host`: the well-known name of the discovery and announcement region

`options`: optional.

`options.logger`: a logger that conforms to `ot-logger`

**This signature is deprecated**. `host` here names both the discovery and announcement region.

#### connect
```
discoveryClient.connect = function(callback)
```

`callback`: `function(err)`. Called when the discovery client is connected to the *discovery region*.

**Retry and failure modes**

`connect` will **not** retry

`connect` will fail if it:
* cannot reach the well known discovery server
* the server replies with a bad status
* the server fails to reply with a full update

#### announce
```
discoveryClient.announce = function(announcement, callback)
```

`announcement`: a hash `{serviceType: 'string', serviceUri: 'string'}`. This hash is not modified.

`callback`: `function(err, lease)`. Called when the announcement has succeeded in all *announcement regions*.

**Retry and failure modes**

`announce` will **not retry**

`announce` will fail if the announcement fails in any region.

`announce` will fail in a region if it:
* cannot reach the well known discovery server
* the discovery server replies with a bad status
* the discovery server fails to reply with a full update
* the discovery server replies correctly, but names no discovery service servers
* the discovery service server picked fails to announce, and there are no more more discovery service servers left to fail over to

**NOTE** do not retry `announce`. `announce` will retry all failed `announcements` every `heartbeat`, or 10 seconds.

#### unannounce
```
discoveryClient.unannounce = function(lease, callback)
```

`lease`: the `lease` returned from `announce`

`callback`: `function(err)`. called when the unannouncement succeeds.

**Retry and failure modes**

`unannounce` will **not retry**

`unannounce` will fail if the unannouncement fails in any region.

`unannounce` will fail in a region if it:
* cannot reach the well known discovery server
* the discovery server fails to reply with a full update
* the discovery server replies correctly, but names no discovery service servers
* the discovery service server picked fails to unannounce, and there are no more more discovery service servers left to fail over to

#### find
```
discoveryClient.find = function(service)
```

`service`: the service to find

`return value`: a URI of that service

This completes synchronously. `find` will pick servers that match the *discovery region* if possible, and if none exist, will fall back to servers in any other region. `find` will randomly pick one server out of all servers announcing as that `service`.

`undefined` is returned if no service matches in the *discovery region*.

#### disconnect
```
discoveryClient.disconnect = function()
```

This completes synchronously. This disconnects all open requests and cancels all heartbeats.


### [Contributing] (CONTRIBUTING.md)
### [Roadmap] (ROADMAP.md)

