describe('discovery', function(){
  var discovery = require("../discovery"),
      should = require("should"),
      disco, host, servers;

  before(function(done){
    disco = new discovery("127.0.0.1:8888", { logger: { log: function(log){}, error: function(err){}}});
    disco.connect(function(err, h, s){
      if(err){
        throw err;
      }

      host = h;
      servers = s;
      done();
    });
  });

  it('should connect', function(){
    host.should.equal('127.0.0.1:8888');
  });

  it('should announce itself', function(done){
    disco.announce({
      serviceType: "myservice",
      serviceUri: "http://myservice-2.domain.com"
    },function(err, lease){

      should.not.exist(err);
      lease.serviceType.should.equal("myservice");
      done(err);
    });
  });

  it('should unannounce itself', function(done){
    disco.unannounce({
        serviceType: 'myservice',
        annoucementId: '3',
        serviceUri: 'http://myservice-2.domain.com'
      },function(){
        
        done();
    });
  });

  it('should pick a random server by serviceType', function(){
    var result = disco.find("myservice");
    result.should.eql("http://myservice-1.domain.com");
  });

  it('should return all servers for serviceType', function(){
    var result = disco.findAll("myservice");
    result.length.should.eql(1);
    result[0].should.eql("http://myservice-1.domain.com");
  });
});
