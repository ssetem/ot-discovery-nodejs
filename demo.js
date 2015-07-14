var discovery = require('./discovery');
var terminalArg = process.argv[2];
if(!terminalArg) {
  console.error("Please specify discovery server, e.g. node demo.js <discovery server url>");
  return;
}
var disco = new discovery(terminalArg);
disco.onError(function(error) {
  console.warn(error);
});
disco.onUpdate(function(update) {
  console.log(update);
});
disco.connect(function(error, host, servers) {
  console.log("Discovery environment '" + host + "' has servers: " + servers);
  disco.announce({
    serviceType: "node-discovery-demo",
    serviceUri: "fake://test"
  }, function (error, lease) {
    if (error) {
      console.error(error);
      return;
    }
    console.log("Announced as: " + JSON.stringify(lease));
    setTimeout(function() {
      console.log("Unannouncing " + lease.announcementId);
      disco.unannounce(lease);
      setTimeout(process.exit, 2000);
    }, 20000);
  });
});

setInterval(function() {
  console.log("Demo service at: " + disco.find("node-discovery-demo"));
}, 5000);
