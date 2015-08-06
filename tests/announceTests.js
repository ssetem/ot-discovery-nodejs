var assert = require('assert');
var nock = require('nock');
var discovery = require('./../discovery.js');
var constants = require('./testConstants.js');
var fullUpdate;
var noUpdate;
var announcement;
var announcementFailure;
var announce;

describe('# announce tests', function(){
  beforeEach(function(done){
    nock.cleanAll();
    nock.disableNetConnect();

    announcement = {
      "announcementId":"my-new-service-id",
      "staticAnnouncement":false,
      "announceTime":"2015-04-02T23:14:13.773Z",
      "serviceType":"my-new-service",
      "serviceUri":"http://my-new-service:8080"
    }

    announcementFailure = {
      "announcementId":"my-new-service-failed-id",
      "staticAnnouncement":false,
      "announceTime":"2015-04-02T23:14:13.773Z",
      "serviceType":"my-new-service-failed",
      "serviceUri":"http://my-new-service:8080"
    }

      fullUpdate = nock(constants.DISCOVERY_URL)
            .get('/watch')
            .reply(200, {
              "fullUpdate":true,
              "index":100,
              "deletes":[],
              "updates":[
                  {
                    "announcementId":"discoveryId",
                    "staticAnnouncement":false,
                    "announceTime":"2015-03-30T18:26:52.178Z",
                    "serviceType":"discovery",
                    "serviceUri":constants.DISCOVERY_SERVER_URLS[0]
                  },
                  {
                    "announcementId":"myserviceId",
                    "staticAnnouncement":false,
                    "announceTime":"2015-03-30T18:26:52.178Z",
                    "serviceType":"myservice",
                    "serviceUri":"http://1.1.1.1:2"
                  }
                ]
              });

    noUpdate = nock(constants.DISCOVERY_SERVER_URLS[0])
            .get('/watch?since=' + 101)
            .delayConnection(10000)
            .reply(204);

    announce = nock(constants.DISCOVERY_SERVER_URLS[0])
            .post('/announcement', announcement)
                  .reply(201, announcement);

    announcementFailure = nock(constants.DISCOVERY_SERVER_URLS[0])
            .post('/announcement', announcementFailure)
                  .reply(500, announcementFailure);

    done();
   });

  afterEach(function(done) {
    nock.cleanAll();
    nock.enableNetConnect();
    done();
  });

    it('should announce calling /announce endpoint', function (done) {
       var disco = new discovery(constants.DISCOVERY_HOST, {
      logger: {
        log: function(level, log, update){ console.log(log); },
        error: function(){ },
      }
    });

    disco.connect(function(error, host, servers) {
      fullUpdate.done();
      disco.announce(announcement, function (error, lease) {
      });
    });

    setTimeout(function() {
      noUpdate.done();
      announce.done();
      done();
    }, 1000);
    });

    it('should take server out of rotation on announcement failure', function (done) {
       var disco = new discovery(constants.DISCOVERY_HOST, {
      logger: {
        log: function(level, log, update){ console.log(log); },
        error: function(){ },
      }
    });

    disco.connect(function(error, host, servers) {
      fullUpdate.done();
      assert.equal(1, disco.servers.length);
      assert.equal(constants.DISCOVERY_SERVER_URLS[0], disco.servers[0]);
      disco.announce(announcementFailure, function (error, lease) {
      });
    });

    setTimeout(function() {
      noUpdate.done();
      assert.equal(0, disco.servers.length);
      done();
    }, 1000);
    })
});
