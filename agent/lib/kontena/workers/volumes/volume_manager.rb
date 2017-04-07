require_relative '../../models/volume'

module Kontena::Workers::Volumes
  class VolumeManager
    include Celluloid
    include Celluloid::Notifications
    include Kontena::Logging
    include Kontena::Helpers::RpcHelper
    include Kontena::Helpers::WaitHelper
    include Kontena::Observer

    attr_reader :node

    def initialize(autostart = true)
      @workers = {}
      subscribe('volume:update', :on_update_notify)
      async.start if autostart
    end

    def start
      observe(Actor[:node_info_worker]) do |node|
        @node = node
      end
      wait_until!('waiting for node info', interval: 0.5) { self.node }
      populate_volumes_from_docker
      loop do
        populate_volumes_from_master
        sleep 30
      end
    end

    def on_update_notify(_, _)
      populate_volumes_from_master
    end

    def populate_volumes_from_master
      exclusive {
        response = rpc_request("/node_volumes/list", [node.id])

        # sanity-check
        unless response['volumes'].is_a?(Array)
          error "Invalid response from master: #{response}"
          return
        else
          debug "got volumes from master: #{response}"
        end

        volumes = response['volumes'].map{ |v| Kontena::Models::Volume.new(v) }

        terminate_volumes(volumes.map {|v| v.volume_instance_id })

        volumes.each do |volume|
          ensure_volume(volume)
        end
      }
    rescue Kontena::RpcClient::Error => exc
      warn "failed to get list of service pods from master: #{exc}"
    end

    def populate_volumes_from_docker
      info "syncing volumes from docker"
      Docker::Volume.all.each do |volume|
        sync_volume_to_master(volume)
      end
    end

    # @param [Kontena::Models::Volume] volume
    def ensure_volume(volume)
      debug "ensuring volume existence: #{volume.inspect}"
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
        'name' => data['Name'],
        'volume_instance_id' => data.dig('Labels', 'io.kontena.volume_instance.id'),
        'volume_id' => data.dig('Labels', 'io.kontena.volume.id')
      }
      rpc_client.async.request('/node_volumes/set_state', [node.id, volume])
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
        volume_instance_id = volume.info.dig('Labels', 'io.kontena.volume_instance.id')
        if volume_instance_id
          unless current_ids.include?(volume_instance_id)
            info "removing volume: #{volume.id}"
            volume.remove
          end
        end
      end
    end
  end
end
