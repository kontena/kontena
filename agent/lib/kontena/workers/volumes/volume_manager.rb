require_relative '../../models/volume'

module Kontena::Workers::Volumes
  class VolumeManager
    include Celluloid
    include Celluloid::Notifications
    include Kontena::Logging
    include Kontena::Helpers::RpcHelper
    include Kontena::Helpers::WaitHelper

    attr_reader :node

    def initialize(autostart = true)
      @workers = {}
      subscribe('agent:node_info', :on_node_info)
      subscribe('volume:update', :on_update_notify)
      async.start if autostart
    end

    def start
      wait!(interval: 0.5, message: 'waiting for node info') { self.node }
      populate_volumes_from_docker
      loop do
        populate_volumes_from_master
        sleep 30
      end
    end

    # @param [String] topic
    # @param [Node] node
    def on_node_info(topic, node)
      @node = node
    end

    def on_update_notify(_, _)
      populate_volumes_from_master
    end

    def populate_volumes_from_master
      exclusive {
        request = rpc_client.request("/node_volumes/list", [node.id])
        response = request.value
        unless response['volumes'].is_a?(Array)
          warn "failed to get list of volumes from master: #{response['error']}"
          return
        end
        debug "got volumes from master: #{response}"

        volumes = response['volumes']

        terminate_volumes(volumes.map {|v| v.dig('labels','io.kontena.volume.id')})

        volumes.each do |s|
          ensure_volume(Kontena::Models::Volume.new(s))
        end
      }
    end

    def populate_volumes_from_docker
      info "syncing volumes from docker"
      Docker::Volume.all.each do |volume|
        sync_volume_to_master(volume)
      end
    end

    # @param [Kontena::Models::Volume] volume
    def ensure_volume(volume)
      debug "ensuring volume: #{volume.inspect}"
      begin
        Docker::Volume.get(volume.name)
      rescue Docker::Error::NotFoundError
        info "creating volume"
        v = Docker::Volume.create(volume.name, {
          'Driver' => volume.driver,
          'DriverOpts' => volume.driver_opts,
          'Labels' => volume.labels
        })
        sync_volume_to_master(v)
      rescue => exc
        error "#{exc.class.name}: #{exc.message}"
        error exc.backtrace.join("\n") if exc.backtrace
      end
    end

    # @param [Kontena::Models::Volume] volume
    def sync_volume_to_master(docker_volume)
      data = docker_volume.info
      volume = {
        'id' => docker_volume.id,
        'name' => data['Name'],
        'volume_id' => data.dig('Labels', 'io.kontena.volume.id')
      }
      rpc_client.async.notification('/node_volumes/set_state', [node.id, volume])
    end

    def volume_exist?(volume_name)
      begin
        debug "volume #{volume_name} exists"
        true if Docker::Volume.get(volume_name)
      rescue Docker::Error::NotFoundError
        debug "volume #{volume_name} does NOT exist"
        false
      end
    end

    def terminate_volumes(current_ids)
      Docker::Volume.all.each do |volume|
        volume_id = volume.info.dig('Labels', 'io.kontena.volume.id')
        if volume_id
          unless current_ids.include?(volume_id)
            info "removing volume: #{volume.id}"
            volume.remove
          end
        end
      end
    end
  end
end
