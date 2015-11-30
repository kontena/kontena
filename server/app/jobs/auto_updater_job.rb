require 'celluloid'
require 'httpclient'

class AutoUpdaterJob
  include Celluloid

  attr_reader :client

  def initialize
    @client = HTTPClient.new
    async.perform
  end

  def perform
    sleep 5 # just to keep things calm
    check_version
    every(1.day.to_i) do
      check_version
    end
  end

  def check_version
    data = {
        version: ::Server::VERSION,
        stats: {
            users: User.count,
            grids: Grid.count,
            nodes: HostNode.count,
            services: GridService.count,
            containers: Container.count
        }
    }
    options = {
        header: headers,
        body: JSON.dump(data)
    }
    client.post('https://update.kontena.io/v1/master', options)
  rescue
  end

  def headers
    {'Accept' => 'application/json', 'Content-Type' => 'application/json'}
  end
end
