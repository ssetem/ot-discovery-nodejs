Discovery Client
---

Client for OT service discovery.

installation:

```
npm install ot-discovery-nodejs
```

usage:

for a full example, see demo.js

```
var discovery = require("ot-discovery-nodejs");

var disco = new discovery("discovery-server.mydomain.com", { /* options */});
```

options:

```
{
  logger: { // a logger object which implements the following signature
    log: function(log){},
    error: function(error){}
  }
}
```

Using with ot-logger

```
new discovery("discovery-server.mydomain.com", { logger: require("ot-logger") });
```
