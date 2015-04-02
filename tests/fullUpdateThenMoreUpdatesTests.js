var assert = require("assert");
var nock = require('nock');
var discovery = require('./../discovery.js');
var constants = require('./testConstants.js');
var fullUpdate;
var noUpdate;

describe('#full update followed by some updates', function(){
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
										"announcementId":"discovery",
										"staticAnnouncement":false,
										"announceTime":"2015-03-30T18:26:52.178Z",
										"serviceType":"discovery",
										"serviceUri":constants.DISCOVERY_SERVER_URLS[0]
									},
									{
										"announcementId":"old",
										"staticAnnouncement":false,
										"announceTime":"2015-03-30T18:26:52.178Z",
										"serviceType":"my-service",
										"serviceUri":"http://1.1.1.1:2"
									}
								]
							});

		smallUpdate = nock(constants.DISCOVERY_SERVER_URLS[0])
						.get('/watch?since=' + 101)
						.reply(200, {
							"fullUpdate":false,
							"index":101,
							"deletes":['old'],
							"updates":[{
										"announcementId":"new1",
										"staticAnnouncement":false,
										"announceTime":"2015-03-30T18:26:52.178Z",
										"serviceType":"my-service-new1",
										"serviceUri":"http://2.2.2.2:2"
									},
									{
										"announcementId":"new2",
										"staticAnnouncement":false,
										"announceTime":"2015-03-30T18:26:52.178Z",
										"serviceType":"my-service-new2",
										"serviceUri":"http://3.3.3.3:3"
									}]
							});

		noUpdate = nock(constants.DISCOVERY_SERVER_URLS[0])
						.get('/watch?since=' + 102)
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
			smallUpdate.done(); 
			noUpdate.done();
			var announcements = disco.state.announcements;
			assert.equal(3, Object.keys(disco.state.announcements).length);
			assert.equal(true, announcements.hasOwnProperty('discovery'));
			assert.equal(true, announcements.hasOwnProperty('new1'));
			assert.equal(true, announcements.hasOwnProperty('new2'));
			assert.equal('discovery', announcements['discovery'].serviceType);
			assert.equal('my-service-new1', announcements['new1'].serviceType);
			assert.equal('my-service-new2', announcements['new2'].serviceType);
			done(); 
		}, 1000);
    })
 });