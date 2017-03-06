require_relative 'fixnum_helper'
require_relative 'container_info_mapper'

module Rpc
  class ContainerHandler
    include Celluloid
    include FixnumHelper
    include Logging

    attr_accessor :logs_buffer_size
    attr_accessor :stats_buffer_size

    def initialize(grid)
      @grid = grid
      @logs = []
      @stats = []
      @cached_container = nil
      @logs_buffer_size = 5
      @stats_buffer_size = 5
      @db_session = ContainerLog.collection.session.with(
        write: {
          w: 0, fsync: false, j: false
        }
      )
    end

    # @param [Hash] data
    def save(data)
      info_mapper = ContainerInfoMapper.new(@grid)
      info_mapper.from_agent(data)
    end

    # @param [Hash] data
    def log(data)
      container = cached_container(data['id'])
      if container
        if data['time']
          created_at = Time.parse(data['time'])
        else
          created_at = Time.now.utc
        end
        @logs << {
          grid_id: @grid.id,
          host_node_id: container['host_node_id'],
          grid_service_id: container['grid_service_id'],
          instance_number: container['instance_number'],
          container_id: container['_id'],
          created_at: created_at,
          name: container['name'],
          type: data['type'],
          data: data['data']
        }
        if @logs.size >= @logs_buffer_size
          flush_logs
        end
      end
    end

    def flush_logs
      @db_session[:container_logs].insert(@logs)
      @logs.clear
    end

    # @param [Hash] data
    def health(data)
      container = Container.find_by(
        grid_id: @grid.id, container_id: data['id']
      )
      if container
        container.set(
          health_status: data['status'],
          health_status_at: Time.now
        )
        MongoPubsub.publish(GridServiceHealthMonitorJob::PUBSUB_KEY, id: container.grid_service.id)
      else
        warn "health status update failed, could not find container for id: #{data['id']}"
      end
    end

    # @param [Hash] data
    def stat(data)
      container = cached_container(data['id'])
      if container
        data = fixnums_to_float(data)
        time = data['time'] ? Time.parse(data['time']) : Time.now.utc
        @stats << {
          grid_id: @grid.id,
          grid_service_id: container['grid_service_id'],
          container_id: container['_id'],
          spec: data['spec'],
          cpu: data['cpu'],
          memory: data['memory'],
          filesystem: data['filesystem'],
          diskio: data['diskio'],
          network: data['network'],
          created_at: time
        }
        if @stats.size >= @stats_buffer_size
          flush_stats
        end
      end
    end

    def flush_stats
      @db_session[:container_stats].insert(@stats.dup)
      @stats.clear
    end

    # @param [Hash] data
    def event(data)
      container = cached_container(data['id'])
      if container
        if data['status'] == 'destroy'
          container = Container.instantiate(container)
          container.destroy
        elsif data['status'] == 'deployed'
          container = Container.instantiate(container)
          container.set(:deploy_rev => data['deploy_rev'])
        end
      end
    end

    # @param [String] id
    # @return [Hash, NilClass]
    def cached_container(id)
      if @cached_container && @cached_container['container_id'] == id
        container = @cached_container
      else
        container = @db_session[:containers].find(
            grid_id: @grid.id, container_id: id
          ).limit(1).one
        @cached_container = container if container
      end

      container
    end
  end
end
