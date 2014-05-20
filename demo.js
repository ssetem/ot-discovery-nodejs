var discovery = require('./discovery');

var disco = new discovery.DiscoveryClient("discovery-proxy.proxy.mesos-vpcqa.otenv.com");
disco.onError(function(error) {
  console.warn(error);
});
disco.onUpdate(function(update) {
  console.log(update);
  console.log(disco.state);
});
disco.connect(function(error, host, servers) {
  console.log("Discovery environment '" + host + "' has servers: " + servers);
});

setInterval(function() { console.log("Demo service at: " + disco.find("demo")); }, 5000);
