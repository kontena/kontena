require_relative '../../models/volume'

module Kontena::Workers::Volumes
  class VolumeManager
    include Celluloid
    include Celluloid::Notifications
    include Kontena::Logging
    include Kontena::Helpers::RpcHelper
    include Kontena::Observer::Helper

    class DriverMismatchError < StandardError
    end

    attr_reader :node

    def initialize(autostart = true)
      @workers = {}
      subscribe('volume:update', :on_update_notify)
      async.start if autostart
    end

    def start
      @node = observe(Actor[:node_info_worker].observable, timeout: 300.0)
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
        unless volume_exist?(volume.name, volume.driver)
          info "creating volume"
          v = Docker::Volume.create(volume.name, {
            'Driver' => volume.driver,
            'DriverOpts' => volume.driver_opts,
            'Labels' => volume.labels
          })
          sync_volume_to_master(v)
        end
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
      # Only send "managed" volumes to server
      if volume['volume_instance_id']
        rpc_client.async.request('/node_volumes/set_state', [node.id, volume])
      else
        debug "Skip sending un-managed volume: #{volume['name']}"
      end
    end

    # Checks if given volume exists with the expected driver
    #
    # @param [String] name of the volume
    # @param [String] driver to expect on the volume if already existing
    # @raise [DriverMismatchError] If the volume is found but using a different driver than expected
    def volume_exist?(volume_name, driver)
      begin
        debug "volume #{volume_name} exists"
        volume = Docker::Volume.get(volume_name)
        if volume && volume.info['Driver'] == driver
          return true
        elsif volume && volume.info['Driver'] != driver
          raise DriverMismatchError.new("Volume driver not as expected. Expected #{driver}, existing volume has #{volume.info['Driver']}")
        end
      rescue Docker::Error::NotFoundError
        debug "volume #{volume_name} does NOT exist"
        false
      rescue => error
        abort error
      end
    end

    def terminate_volumes(current_ids)
      Docker::Volume.all.each do |volume|
        volume_instance_id = volume.info.dig('Labels', 'io.kontena.volume_instance.id')
        if volume_instance_id
          unless current_ids.include?(volume_instance_id)
            info "removing volume: #{volume.id}"
            begin
              volume.remove
              info "removed volume: #{volume.id} succesfully"
            rescue => exc
              warn "removing volume #{volume.id} failed: #{exc.class} #{exc.message}"
            end
          end
        end
      end
    end
  end
end
