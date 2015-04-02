var assert = require("assert");
var nock = require('nock');
var discovery = require('./../discovery.js');
var DISCOVERY_HOST = 'discovery-test-uswest2.otenv.com'
var DISCOVERY_URL = 'http://' + DISCOVERY_HOST;
var DISCOVERY_SERVER_URLS = ['http://0.0.0.0:0', 'http://0.0.0.0:1', 'http://0.0.0.0:2']
var fullUpdate;
var noUpdate;

describe('#full update followed by no updates', function(){
	beforeEach(function(done){
		nock.disableNetConnect();
		this.timeout(5000);

	    fullUpdate = nock(DISCOVERY_URL)
						.get('/watch')
						.reply(200, {
							"fullUpdate":true,
							"index":100,
							"deletes":[],
							"updates":[
									{
										"announcementId":"0f76787c-dfaf-4ef6-9cb7-48899af7689e",
										"staticAnnouncement":false,
										"announceTime":"2015-03-30T18:26:52.178Z",
										"serviceType":"discovery",
										"serviceUri":DISCOVERY_SERVER_URLS[0]
									},
									{
										"announcementId":"0f76787c-dfaf-4ef6-9cb7-48899af7689f",
										"staticAnnouncement":false,
										"announceTime":"2015-03-30T18:26:52.178Z",
										"serviceType":"my-service",
										"serviceUri":"http://1.1.1.1:2"
									}
								]
							});

		noUpdate = nock(DISCOVERY_SERVER_URLS[0])
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
	     var disco = new discovery(DISCOVERY_HOST, {
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
			// TODO: more granular asserts 
			assert.equal(2, Object.keys(disco.state.announcements).length);
			done(); 
		}, 1000);
    })
});