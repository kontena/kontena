require_relative 'container_info_mapper'

module Rpc
  class ContainerHandler
    include Logging

    attr_accessor :stats_buffer_size

    def initialize(grid)
      @grid = grid
      @stats = []
      @cached_containers = {}
      @stats_buffer_size = 5
      @containers_cache_size = 50
      @db_session = ContainerLog.collection.client.with(
        write: {
          w: 0, fsync: false, j: false
        }
      )
    end

    # @param [Hash] data
    def save(data)
      info_mapper = ContainerInfoMapper.new(@grid)
      info_mapper.from_agent(data)

      {}
    end

    # @param [String] node_id
    # @param [Array<String>] ids
    def cleanup(node_id, ids)
      node = @grid.host_nodes.find_by(node_id: node_id)
      if node
        @grid.containers.unscoped.where(
          :host_node_id => node.id,
          :container_id.in => ids
        ).destroy
      end
    end

    # @param [Array<Hash>] logs
    def log_batch(logs)
      batch = logs.map { |data| self.build_log_item(data) }.compact
      batch_size = batch.size
      if batch_size > 0
        flush_logs(batch)
        batch.clear
        gc_cache
      end
      { count: batch_size }
    end

    # @param [Hash] data
    # @return [Hash,NilClass]
    def build_log_item(data)
      container = cached_container(data['id'])
      return nil unless container

      if data['time']
        created_at = Time.xmlschema(data['time'])
      else
        created_at = Time.now.utc
      end
      {
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
    end

    # @param [Hash] data
    def health(data)
      container = Container.find_by(
        grid_id: @grid.id, container_id: data['id']
      )
      if container
        container.set_health_status(data['status'])
        if container.grid_service
          MongoPubsub.publish(GridServiceHealthMonitorJob::PUBSUB_KEY, id: container.grid_service.id.to_s)
        end
      else
        warn "health status update failed, could not find container for id: #{data['id']}"
      end
    end

    # @param [Hash] data
    def stat(data)
      container = cached_container(data['id'])
      if container
        time = data['time'] ? Time.parse(data['time']) : Time.now.utc
        @stats << {
          grid_id: @grid.id,
          host_node_id: container['host_node_id'],
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
          gc_cache
        end
        if container['grid_service_id'] && container['instance_number'] && container['container_type'] == 'container'.freeze
          update_grid_service_instance_stats(container, data)
        end
      end
    end

    # @param [Hash] data
    def event(data)
      container = cached_container(data['id'])
      if container
        if data['status'] == 'destroy'
          container = Container.instantiate(container)
          container.destroy
        end
      end

      {}
    end

    # @param [Array<Hash>]
    def flush_logs(logs)
      @db_session[:container_logs].insert_many(logs)
    end

    def flush_stats
      @db_session[:container_stats].insert_many(@stats.dup)
      @stats.clear
    end

    # @param container [Hash]
    # @param data [Hash]
    def update_grid_service_instance_stats(container, data)
      @db_session[:grid_service_instances].find_one_and_update(
        { grid_service_id: container['grid_service_id'], instance_number: container['instance_number'] },
        {
          :'$set' => {
            latest_stats: {
              cpu: data['cpu'],
              memory: data['memory']
            }
          }
        }
      )
    end

    def gc_cache
      if @cached_containers.keys.size > @containers_cache_size
        (@containers_cache_size / 5).times { @cached_containers.shift }
      end
    end

    # @param [String] id
    # @return [Hash, NilClass]
    def cached_container(id)
      if @cached_containers[id]
        container = @cached_containers[id]
      else
        container = @db_session[:containers].find(
            grid_id: @grid.id, container_id: id
          ).limit(1).first
        @cached_containers[id] = container if container
      end

      container
    end
  end
end
