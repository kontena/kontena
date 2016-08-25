class RpcServer

  Signal.trap('SIGTERM') {
    10.times { puts "SERVER STOPPING EVENT MACHINE" }
    EM.stop
  }
  
  HANDLERS = {
  }

  class Error < StandardError
    attr_accessor :code, :message, :backtrace

    def initialize(code, message, backtrace = nil)
      self.code = code
      self.message = message
      self.backtrace = backtrace
    end
  end

  ##
  # @param [String] grid_id
  # @param [Array] message msgpack-rpc request array
  # @return [Array]
  def self.handle_request(grid_id, message)
    msg_id = message[1]
    grid = Grid.find(grid_id)
    return [1, msg_id, {error: 'grid not found'}, nil] if grid.nil?

    handler = message[2].split('/')[1]
    method = message[2].split('/')[2]
    if klass = HANDLERS[handler]
      begin
        result = klass.new(grid).send(method, *message[3])
        return [1, msg_id, nil, result]
      rescue RpcServer::Error => exc
        return [1, msg_id, {code: exc.code, message: exc.message, backtrace: exc.backtrace}, nil]
      rescue => exc
        puts "#{exc.class.name}: #{exc.message}"
        puts exc.backtrace.join("\n")
        return [1, msg_id, {code: 500, message: "#{exc.class.name}: #{exc.message}", backtrace: exc.backtrace}, nil]
      end
    else
      return [1, msg_id, {error: 'service not implemented'}, nil]
    end
  end
end
