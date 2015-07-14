var assert = require('assert');
var nock = require('nock');
var constants = require('./testConstants.js');
var fullUpdate;
var noUpdate;
var announcement;
var announcementFailure;

describe('# announce tests', function(){
  this.timeout(60000)
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
      .delayConnection(1000)
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
    if(this.disco && this.disco.dispose) {
      this.disco.dispose()
    }
    nock.cleanAll();
    nock.enableNetConnect();
    done();
  });

    it('should announce calling /announce endpoint', function (done) {
      var disco = this.disco = new discovery(constants.DISCOVERY_HOST);

      disco.connect(function(error, host, servers) {
        fullUpdate.done();
        assert.equal(constants.DISCOVERY_HOST, host)
        assert.deepEqual(servers, [constants.DISCOVERY_SERVER_URLS[0]])
        disco.announce(announcement, function (error, lease) {
          assert.deepEqual(lease, announcement)
          noUpdate.done();
          announce.done();
          done()
        });
      });
    });

    it('should take server out of rotation on announcement failure', function (done) {
      var disco = this.disco = new discovery(constants.DISCOVERY_HOST, constants.DISCOVERY_OPTIONS);
      disco.discoveryAnnouncer.ANNOUNCE_ATTEMPTS=1
      disco.reconnect(function(error, host, servers) {
        fullUpdate.done();
        assert.equal(1, disco.getServers().length);
        assert.equal(constants.DISCOVERY_SERVER_URLS[0], disco.getServers()[0]);
        disco.announce(announcementFailure, function (error, lease) {
          assert(!!error)
          assert.equal(lease, undefined)
          noUpdate.done();
          assert.equal(0, disco.getServers().length);
          done();
        });
      });
    })
});
