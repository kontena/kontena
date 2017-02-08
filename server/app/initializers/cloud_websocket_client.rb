require_relative '../services/cloud/websocket_client'

Cloud::WebsocketClient.configure do |config|
  config.api_uri = Configuration.get('cloud.socket_uri')
end
