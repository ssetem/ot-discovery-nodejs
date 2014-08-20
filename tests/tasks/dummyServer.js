var http = require("http"),
    server = {},
    fullUpdate = {
      fullUpdate: true,
      index: 1,
      deletes: [],
      updates: [
        {
          serviceType: 'discovery',
          announcementId: '1',
          serviceUri: 'http://127.0.0.1:8888'
        },
        {
          serviceType: 'myservice',
          announcementId: '2',
          serviceUri: 'http://myservice-1.domain.com'
        }
      ]
    },
    lease = {
      serviceType: 'myservice',
      announcementId: '3',
      serviceUri: 'http://myservice-2.domain.com'
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
