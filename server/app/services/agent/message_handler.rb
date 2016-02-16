module Agent
  class MessageHandler
    include EventStream::GridEventNotifier
    include Logging

    attr_reader :db_session

    ##
    # @param [Queue] queue
    def initialize(queue)
      @queue = queue
      @logs = []
      @stats = []
      @cached_grid = nil
      @cached_container = nil
      @db_session = ContainerLog.collection.session.with(
        write: {
          w: 0, fsync: false, j: false
        }
      )
    end

    def run
      Thread.new {
        i = 0
        loop do
          begin
            message = @queue.pop
            self.handle_message(message)
            i += 1
            Thread.pass
            if i > 100
              i = 0
              @cached_grid = nil
            end
          rescue => exc
            error "#{exc.class.name}: #{exc.message}"
            error exc.backtrace.join("\n") if exc.backtrace
          end
        end
      }
    end

    ##
    # @param [Hash] message
    def handle_message(message)
      grid = cached_grid(message['grid_id'])
      return if grid.nil?

      data = message['data']
      case data['event']
        when 'node:info'.freeze
          self.on_node_info(grid, data['data'])
        when 'container:info'.freeze
          self.on_container_info(grid, data['data'])
        when 'container:event'.freeze
          self.on_container_event(grid, data['data'])
        when 'container:log'.freeze
          self.on_container_log(grid, message['node_id'], data['data'])
        when 'container:stats'.freeze
          self.on_container_stat(grid, data['data'])
        else
          error "unknown event: #{message}"
      end
    end

    ##
    # @param [Grid] grid
    # @param [Hash] data
    def on_node_info(grid, data)
      node = grid.host_nodes.find_by(node_id: data['ID'])
      if !node
        node = grid.host_nodes.build
      end
      node.attributes_from_docker(data)
      node.save!
      trigger_grid_event(node.grid, 'node', 'update', HostNodeSerializer.new(node).to_hash)
      node
    end

    ##
    # @param [Grid] grid
    # @param [Hash] data
    def on_container_info(grid, data)
      info_mapper = ContainerInfoMapper.new(grid)
      info_mapper.from_agent(data)
    end

    ##
    # @param [Grid] grid
    # @param [Hash] data
    def on_container_event(grid, data)
      container = grid_container(grid.id, data['id'])
      if container
        if data['status'] == 'destroy'
          container = Container.instantiate(container)
          trigger_grid_event(grid, 'container', 'delete', ContainerSerializer.new(container).to_hash)
          container.destroy
        elsif data['status'] == 'deployed'
          container = Container.instantiate(container)
          container.set(:deploy_rev => data['deploy_rev'])
          trigger_grid_event(grid, 'container', 'update', ContainerSerializer.new(container).to_hash)
        end
      end
    end

    ##
    # @param [Grid] grid
    # @param [String] node_id
    # @param [Hash] data
    def on_container_log(grid, node_id, data)
      container = cached_container(grid.id, data['id'])
      if container
        if data['time']
          created_at = Time.parse(data['time'])
        else
          created_at = Time.now.utc
        end
        @logs << {
          grid_id: grid.id,
          host_node_id: node_id,
          grid_service_id: container['grid_service_id'],
          container_id: container['_id'],
          created_at: created_at,
          name: container['name'],
          type: data['type'],
          data: data['data']
        }
        if @logs.size >= 5
          flush_logs
        end
      end
    end

    def flush_logs
      db_session[:container_logs].insert(@logs)
      @logs.clear
    end

    ##
    # @param [Grid] grid
    # @param [Hash] data
    def on_container_stat(grid, data)
      return if @queue.length > 100

      container = grid_container(grid.id, data['id'])
      if container
        data = fixnums_to_float(data)
        @stats << {
          grid_id: grid.id,
          grid_service_id: container['grid_service_id'],
          container_id: container['_id'],
          spec: data['spec'],
          cpu: data['cpu'],
          memory: data['memory'],
          filesystem: data['filesystem'],
          diskio: data['diskio'],
          network: data['network']
        }
        if @stats.size >= 5
          db_session[:container_stats].insert(@stats.dup)
          @stats.clear
        end
      end
    end

    ##
    # @param [Hash,Array]
    # @return [Hash,Array]
    def fixnums_to_float(h)
      i = 0
      h.each do |k, v|
        # If v is nil, an array is being iterated and the value is k.
        # If v is not nil, a hash is being iterated and the value is v.
        #
        value = v || k

        if value.is_a?(Hash) || value.is_a?(Array)
          fixnums_to_float(value)
        else
          if !v.nil? && value.is_a?(Bignum)
            h[k] = value.to_f
          elsif v.nil? && value.is_a?(Bignum)
            h[i] = value.to_f
          end
        end
        i += 1
      end
    end

    # @param [ObjectId] grid_id
    # @param [String] id
    # @return [Hash, NilClass]
    def cached_container(grid_id, id)
      if @cached_container && @cached_container['container_id'] == id
        container = @cached_container
      else
        container = grid_container(grid_id, id)
        @cached_container = container if container
      end

      container
    end

    # @param [ObjectId] grid_id
    # @param [String] id
    # @return [Hash, NilClass]
    def grid_container(grid_id, id)
      container = db_session[:containers].find(
          grid_id: grid_id, container_id: id
        ).limit(1).one
    end

    # @param [String] id
    # @return [Grid,NilClass]
    def cached_grid(id)
      if @cached_grid && @cached_grid.id.to_s.freeze == id
        grid = @cached_grid
      else
        grid = Grid.find_by(id: id)
        @cached_grid = grid
      end
      grid
    end
  end
end
