var express = require('express');
var ParseServer = require('parse-server').ParseServer;

var app = express();

// Specify the connection string for your mongodb database
// and the location to your Parse cloud code
var api = new ParseServer({
  databaseURI: process.env.MONGO_URI,
  cloud: '/usr/src/app/cloud/main.js', // Provide an absolute path
  appId: process.env.APP_ID,
  masterKey: process.env.MASTER_KEY,
  fileKey: process.env.FILE_KEY
});

// Serve the Parse API on the root URL
app.use('/', api);

var port = process.env.PORT || 8080;
app.listen(port, function() {
  console.log('parse-server-example running on port ' + port + '.'+ ' appId ' + process.env.APP_ID);
});