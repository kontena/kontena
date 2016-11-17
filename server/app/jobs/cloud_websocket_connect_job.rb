require 'celluloid'
require_relative '../services/logging'

class CloudWebsocketConnectJob
  include Celluloid
  include CurrentLeader
  include Logging
  include ConfigHelper # adds a .config method

  def initialize(perform = true)
    @root_url = ENV['CLOUD_WS_URL']
    async.perform if perform
  end

  def perform
    sleep 0.1
    start_em
    loop do
      if cloud_enabled?
        connect
      else
        disconnect
      end
      sleep 30
    end
  end

  def cloud_enabled?
    config['oauth2.client_id'] && config['oauth2.client_secret']
  end

  def connect
    if @client.nil?
      info 'opening connection to Kontena Cloud'
      @client = Cloud::WebsocketClient.new("#{@root_url}/platform", config['oauth2.client_id'], config['oauth2.client_secret'])
      @client.ensure_connect
    end
    @client
  end

  def disconnect
    if @client
      @client.disconnect
      @client = nil
    end
  end

  def start_em
    EM.epoll
    Thread.new { EventMachine.run } unless EventMachine.reactor_running?
    sleep 0.01 until EventMachine.reactor_running?
  end
end
