require_relative 'rpc/container_handler'
require_relative 'rpc/container_exec_handler'
require_relative 'rpc/node_handler'
require_relative 'rpc/node_service_pod_handler'

class RpcServer
  include Celluloid
  include Logging

  QUEUE_SIZE = 1000
  QUEUE_WATCH_PERIOD = 60 # once in a minute
  QUEUE_DROP_NOTIFICATIONS_LIMIT = (RpcServer::QUEUE_SIZE * 0.8)

  def self.queue
    @queue ||= SizedQueue.new(QUEUE_SIZE)
  end

  # @param grid_id [String]
  # @param rpc_request [Array{0, Integer, String, Array}] MsgPack-RPC request
  # @yield [rpc_response]
  def self.handle_rpc_request(grid_id, rpc_request, &block)
    self.queue << [grid_id, rpc_request, block]
  end

  # @param grid_id [String]
  # @param rpc_notification [Array{2, String, Array}] MsgPack-RPC notification
  def self.handle_rpc_notification(grid_id, rpc_notification)
    if self.queue.size > QUEUE_DROP_NOTIFICATIONS_LIMIT # too busy to handle notifications
      @msg_dropped += 1
      return
    end

    self.queue << [grid_id, rpc_notification, nil]
  end

  def self.msg_dropped
    @msg_dropped
  end

  HANDLERS = {
    'containers' => Rpc::ContainerHandler,
    'container_exec' => Rpc::ContainerExecHandler,
    'nodes' => Rpc::NodeHandler,
    'node_service_pods' => Rpc::NodeServicePodHandler,
    'node_volumes' => Rpc::NodeVolumeHandler
  }

  finalizer :finalize

  class Error < StandardError
    attr_reader :code

    def initialize(code, message)
      @code = code
      super(message)
    end
  end

  attr_reader :handlers

  # @param [SizedQueue] queue
  def initialize(autostart: true)
    @queue = self.class.queue
    @handlers = {}
    @counter = 0

    info "initialized"

    async.process! if autostart
  end

  # XXX: fixup
  def watch_queue
    EM::PeriodicTimer.new(QUEUE_WATCH_PERIOD) do
      if (queue_size = self.rpc_queue.size) > QUEUE_DROP_NOTIFICATIONS_LIMIT
        logger.warn "#{queue_size} messages in queue"
      end
      logger.warn "#{@msg_dropped} dropped notifications" if @msg_dropped > 0
      logger.info "#{@msg_counter / QUEUE_WATCH_PERIOD} messages per second"
      @msg_counter = 0
      @msg_dropped = 0
    end
  end

  def process!
    while data = @queue.pop
      @counter += 1

      grid_id, rpc, block = data

      if block
        block.call(handle_request(grid_id, rpc).as_json)
      else
        handle_notification(grid_id, rpc)
      end

      Thread.pass
    end
  end

  # @param grid_id [String]
  # @param rpc_request [Array{0, Integer, String, Array}] message msgpack-rpc request array
  # @return [Array{1, Integer, Hash, Hash}]
  def handle_request(grid_id, rpc_request)
    msg_type, msg_id, msg_path, msg_params = rpc_request
    _, handler, method = msg_path.split('/')
    if instance = handling_instance(grid_id, handler)
      start_time = Time.now
      begin
        result = instance.send(method, *msg_params)
      rescue RpcServer::Error => exc
        @handlers[grid_id].delete(handler)
        return [1, msg_id, {code: exc.code, message: exc.message}, nil]
      rescue => exc
        error "request #{msg_path} => #{exc.class}: #{exc}"
        error exc
        @handlers[grid_id].delete(handler)
        return [1, msg_id, {code: 500, message: "#{exc.class.name}: #{exc.message}"}, nil]
      else
        dt = Time.now - start_time
        debug "request #{msg_path} => #{result.class} in #{'%.3f' % dt}s"
        return [1, msg_id, nil, result]
      end
    else
      warn "handler #{msg_path} not implemented"
      return [1, msg_id, {code: 501, error: 'service not implemented'}, nil]
    end
  end

  # @param grid_id [String]
  # @param rpc_notification [Array{2, String, Array}] msgpack-rpc notification array
  def handle_notification(grid_id, rpc_notification)
    msg_type, msg_path, msg_params = rpc_notification
    _, handler, method = msg_path.split('/')
    if instance = handling_instance(grid_id, handler)
      start_time = Time.now
      begin
        instance.send(method, *msg_params)
      rescue => exc
        error "notify #{msg_path} => #{exc.class}: #{exc}"
        error exc
        @handlers[grid_id].delete(handler)
      else
        dt = Time.now - start_time
        debug "notify #{msg_path} in #{'%.3f' % dt}s"
      end
    else
      warn "handler #{msg_path} not implemented"
    end
  end

  # @param [String] grid_id
  # @param [String] name
  # @return [Object]
  def handling_instance(grid_id, name)
    return unless HANDLERS[name]

    @handlers[grid_id] ||= {}
    unless @handlers[grid_id][name]
      grid = Grid.find(grid_id)
      if grid
        @handlers[grid_id][name] = HANDLERS[name].new(grid)
      end
    end

    @handlers[grid_id][name]
  end

  def finalize
    info "terminated"
  end
end
