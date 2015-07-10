testConstants = {
  DISCOVERY_HOST: 'discovery-test-uswest2.otenv.com',
  DISCOVERY_URL:   'http://discovery-test-uswest2.otenv.com',
  DISCOVERY_SERVER_URLS: ['http://0.0.0.0:0', 'http://0.0.0.0:1', 'http://0.0.0.0:2'],
  TIMEOUT_MS: 50000,
  DISCOVERY_OPTIONS:{
    logger: {
      log: function(level, log, update){ console.log.apply(console, arguments); },
      error: function(){ },
    }
  }
};

module.exports = testConstants;
