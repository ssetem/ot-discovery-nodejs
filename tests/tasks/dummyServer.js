var http = require("http"),
    fs = require("fs"),
    server = {},
    requestFile = fs.openSync('tests/actual/request.json', 'w'),
    fullUpdate = {
      fullUpdate: true,
      index: 1,
      deletes: [],
      updates: [
        {
          serviceType: 'discovery',
          annoucementId: '1234-5678',
          serviceUri: 'http://127.0.0.1:8888'
        }
      ]
    },
    lease = {
      serviceType: 'myservice',
      annoucementId: '1234-5678',
      serviceUri: 'http://myservice.domain.com'
    };

module.exports = function(grunt){
    grunt.registerTask('start-server', function(){
        server = http.createServer(function(request, response) {
          if(request.method == 'POST'){
            response.writeHead(201, {"content-type": "application/json"});
            response.write(JSON.stringify(lease));
          }else{
            response.writeHead(200, {"content-type": "application/json"});
            response.write(JSON.stringify(fullUpdate));
          }
          
          response.end();
        }).listen(8888);
    });
};
