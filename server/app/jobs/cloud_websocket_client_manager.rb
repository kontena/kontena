require_relative '../services/logging'
require_relative '../services/auth_provider'

class CloudWebsocketClientManager
  include Celluloid
  include Logging
  include ConfigHelper # adds a .config method

  trap_exit :on_actor_exit

  def initialize(perform = true)
    async.perform if perform
  end

  def perform
    update_connection
    every(30.0) do
      update_connection
    end
  end

  def update_connection
    if cloud_enabled?
      connect(socket_api_uri,
        client_id: config['oauth2.client_id'],
        client_secret: config['oauth2.client_secret'],
      )
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
    !config['cloud.socket_uri'].to_s.empty?
  end
  def socket_api_uri
    "#{config['cloud.socket_uri']}/platform"
  end

  def oauth_app_credentials?
    config['oauth2.client_id'] && config['oauth2.client_secret']
  end

  def connect(uri, options)
    if @client.nil?
      @client = Cloud::WebsocketClient.new(uri, **options)
      @client.start

      self.link @client
    end
    @client
  end

  def disconnect
    if @client
      @client.stop # actor terminates itself
    end
  end

  protected

  def client
    @client
  end

  def on_actor_exit(actor, reason)
    if actor == @client
      @client = nil
      info "Client exited: #{reason}"
    else
      warn "Unknown actor #{actor} crash: #{reason}"
    end
  end
end
