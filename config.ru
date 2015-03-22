require './server'
require './app/middlewares/websocket_backend'

$stdout.sync = true

use WebsocketBackend
run Server.app
