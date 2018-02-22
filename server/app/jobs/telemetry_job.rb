require 'httpclient'
require 'digest'
require_relative '../helpers/config_helper'

class TelemetryJob
  include Celluloid
  include ConfigHelper
  include Logging
  include CurrentLeader

  HEADERS = {
    'Accept' => 'application/json',
    'Content-Type' => 'application/json'
  }.freeze

  attr_reader :client

  def initialize
    @client = HTTPClient.new
    async.perform
  end

  def perform
    if stats_enabled? && leader?
      sleep 30 # just to keep things calm
      check_version
    end
    every(1.hours.to_i) do
      check_version if stats_enabled? && leader?
    end
  end

  # @return [Boolean]
  def stats_enabled?
    config['server.telemetry_enabled'].to_s != 'false'
  end

  # @return [Hash]
  def payload
    {
      id: config['server.uuid'],
      version: ::Server::VERSION,
      stats: {
          users: User.count,
          grids: Grid.count,
          nodes: HostNode.count,
          services: GridService.count,
          containers: Container.count
      },
      grids: build_grid_stats
    }
  end

  def check_version
    options = {
        header: HEADERS,
        body: JSON.dump(payload)
    }
    response = client.post('https://update.kontena.io/v1/master', options)
    handle_response(response)
  rescue => exc
    warn "failed to check updates"
  end

  def handle_response(response)
    if response.status_code == 200
      data = JSON.parse(response.body)
      if data['version'] && Gem::Version.new(data['version']) > Gem::Version.new(::Server::VERSION)
        warn "latest version is #{data['version']}, consider upgrading"
      end
    end
  end

  # @return [Array<Hash>]
  def build_grid_stats
    stats = []
    Grid.all.each do |grid|
      stats << build_grid_stat(grid)
    end

    stats
  end

  # @param [Grid] grid
  # @return [Hash]
  def build_grid_stat(grid)
    stat = { id: grid.id.to_s }
    stat[:nodes] = build_node_stats(grid)
    stat[:services] = build_service_stats(grid)
    stat[:usage] = {
      container_hours: stat[:nodes].sum { |n| n[:container_hours] }
    }
    stat
  end

  # @param [Grid] grid
  # @return [Array]
  def build_node_stats(grid)
    nodes = []
    grid.host_nodes.all.each do |node|
      stats = {
        id: node.id.to_s,
        created_at: node.created_at,
        cpus: node.cpus,
        memory: node.mem_total,
        provider: node.host_provider,
        kernel: node.kernel_version,
        os: node.os
      }
      container_seconds = node.host_node_stats.where(
        :created_at.gt => (Time.now - 1.hour).beginning_of_hour
      ).sum(:'usage.container_seconds').to_i
      stats[:container_hours] = container_seconds / 60
      nodes << stats
    end

    nodes
  end

  # @param [Grid] grid
  # @return [Array]
  def build_service_stats(grid)
    services = []
    grid.grid_services.all.each do |service|
      services << {
        id: service.id.to_s,
        created_at: service.created_at,
        deployed_at: service.deployed_at,
        image: Digest::SHA256.hexdigest(service.image_name),
        instances: service.container_count
      }
    end

    services
  end
end
