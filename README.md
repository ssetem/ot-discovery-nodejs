# OT Discovery Client
[![Build Status](https://travis-ci.org/opentable/ot-discovery-nodejs.png?branch=master)](https://travis-ci.org/opentable/ot-discovery-nodejs) [![NPM version](https://badge.fury.io/js/ot-discovery.png)](http://badge.fury.io/js/ot-discovery) ![Dependencies](https://david-dm.org/opentable/ot-discovery-nodejs.png)

Client for OT flavoured service discovery. (Note we are in the process of open-sourcing the entire Opentable discovery stack)

installation:

```
npm install ot-discovery
```

usage:

for a full example, see demo.js

```
var discovery = require("ot-discovery");

var disco = new discovery("discovery-server.mydomain.com", { /* options */});
```

options:

```
{
  logger: { // a logger object which implements the following signature
    log: function(severity, log){} // severity will be one of info, debug, error
  }
}
```

Using with ot-logger

```
new discovery("discovery-server.mydomain.com", { logger: require("ot-logger") });
```
