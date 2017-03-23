require_relative '../services/logging'
require_relative '../services/auth_provider'

class CloudWebsocketConnectJob
  include Celluloid
  include Logging
  include ConfigHelper # adds a .config method

  def initialize(perform = true)
    async.perform if perform
  end

  def perform
    sleep 0.1
    while running?
      update_connection
      sleep 30
    end
  end

  def running? # we can mock this in tests to return false
    true
  end

  def update_connection
    if cloud_enabled?
      connect
    else
      disconnect
    end
  end

  def cloud_enabled?
    kontena_auth_provider? &&
      oauth_app_credentials? &&
      cloud_enabled_in_config? &&
      socket_api_uri?
  end

  def kontena_auth_provider?
    ap = AuthProvider.instance
    ap.valid? && ap.is_kontena?
  end

  def cloud_enabled_in_config?
    config['cloud.enabled'].to_s == 'true'
  end

  def socket_api_uri?
    !Cloud::WebsocketClient.api_uri.to_s.empty?
  end

  def oauth_app_credentials?
    config['oauth2.client_id'] && config['oauth2.client_secret']
  end

  def connect
    if @client.nil?
      @client = init_ws_client(config['oauth2.client_id'], config['oauth2.client_secret'])
      @client.ensure_connect
    end
    @client
  end

  ##
  # return [Cloud::WebsocketClient]
  def init_ws_client(client_id, client_secret)
    Cloud::WebsocketClient.new(client_id, client_secret)
  end

  def disconnect
    if @client
      @client.disconnect
      @client = nil
    end
  end

  protected

  def client
    @client
  end

end
