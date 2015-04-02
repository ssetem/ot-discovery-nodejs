var assert = require('assert');
var nock = require('nock');
var discovery = require('./../discovery.js');
var constants = require('./testConstants.js');
var fullUpdate;
var noUpdate;

describe('#full update followed by no updates', function(){
	beforeEach(function(done){
		nock.disableNetConnect();
		this.timeout(constants.TIMEOUT_MS);

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
						.reply(200, {
							"fullUpdate":false,
							"index":100,
							"deletes":[],
							"updates":[]
							});

		done();
	 });

	afterEach(function(done) {
		nock.enableNetConnect();
		done();
	});

    it('should call watch, watch?since= and correctly populate announcements', function (done){
	     var disco = new discovery(constants.DISCOVERY_HOST, {
		  logger: {
		    log: function(){ },
		    error: function(){ },
		  }
		});

		disco.connect(function(error, host, servers) {
			fullUpdate.done();
		});

		setTimeout(function() { 
			noUpdate.done();
			var announcements = disco.state.announcements;
			assert.equal(true, announcements.hasOwnProperty('discoveryId'));
			assert.equal(true, announcements.hasOwnProperty('myserviceId'));
			assert.equal('discovery', announcements['discoveryId'].serviceType);
			assert.equal('myservice', announcements['myserviceId'].serviceType);
			assert.equal(2, Object.keys(disco.state.announcements).length);
			done(); 
		}, 1000);
    })
});