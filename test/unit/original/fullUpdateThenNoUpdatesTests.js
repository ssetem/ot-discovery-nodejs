var assert = require('assert');
var nock = require('nock');
var constants = require('./testConstants.js');
var fullUpdate;
var noUpdate;

xdescribe('# full update followed by no updates tests', function(){
  beforeEach(function(done){
    nock.cleanAll();
    nock.disableNetConnect();

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

    it('should call watch, watch?since= and correctly populate announcements', function (done){
       var disco = this.disco = new discovery(constants.DISCOVERY_HOST, constants.DISCOVERY_OPTIONS);

    disco.connect(function(error, host, servers) {
      fullUpdate.done();
    });

    var onUpdateReceived = false;
    // there are no updates after fullUpdate in this test,
    // so this method should not fire.
    disco.onUpdate(function(arg1, arg2, arg3) {
      onUpdateReceived = true;
    });

    setTimeout(function() {
      assert.equal(false, onUpdateReceived);
      noUpdate.done();
      var announcements = disco.getAnnouncements();
      assert.equal(true, announcements.hasOwnProperty('discoveryId'));
      assert.equal(true, announcements.hasOwnProperty('myserviceId'));
      assert.equal('discovery', announcements['discoveryId'].serviceType);
      assert.equal('myservice', announcements['myserviceId'].serviceType);
      assert.equal(2, Object.keys(announcements).length);
      done();
    }, 1500);
    })
});
