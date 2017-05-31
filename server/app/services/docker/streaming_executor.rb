module Docker
  class StreamingExecutor
    include Logging

    # @param [Container] container
    # @param [#send,#close] ws
    def initialize(container, ws)
      @container = container
      @ws = ws
      @client = RpcClient.new(container.host_node.node_id)
    end

    # Starts exec session with tty
    # @param [Boolean] shell
    def start_tty(shell)
      create_session
      subscribe_to_session
      register_tty_ws_events(shell)
    end

    # Starts normal exec session (without tty)
    # @param [Boolean] shell
    def start(shell)
      create_session
      subscribe_to_session
      register_run_ws_events(shell)
    end

    def create_session
      @exec_session = @client.request('/containers/create_exec', @container.container_id)
    end

    def subscribe_to_session
      @subscription = MongoPubsub.subscribe("container_exec:#{@exec_session['id']}") do |data|
        if data.has_key?('exit')
          @ws.send(JSON.dump({ exit: data['exit'] }))
          @ws.close
        else
          @ws.send(JSON.dump({ stream: data['stream'], chunk: data['chunk'] }))
        end
      end
    end

    # @param [Boolean] shell
    def register_tty_ws_events(shell)
      init = true
      @ws.on(:message) do |event|
        if init == true
          begin
            data = JSON.parse(event.data)
            if data.has_key?('cmd')
              if shell
                cmd = ['/bin/sh', '-c', data['cmd'].join(' ')]
              else 
                cmd = data['cmd']
              end
              @client.notify('/containers/run_exec', @exec_session['id'], cmd, true)
              init = false
            end
          rescue JSON::ParserError
            error "invalid handshake json"
            @ws.close
          end
        else
          begin
            input = JSON.parse(event.data)
            @client.notify('/containers/tty_input', @exec_session['id'], input['stdin']) if input.has_key?('stdin')
          rescue JSON::ParserError
            error "invalid tty_input json"
            @ws.close
          end
        end
      end

      @ws.on(:close) do |event|
        @client.notify('/containers/terminate_exec', @exec_session['id'])
        @subscription.terminate if @subscription
      end
    end

    # @param [Boolean] shell
    def register_run_ws_events(shell)
      @ws.on(:message) do |event|
        begin
          data = JSON.parse(event.data)
          if data.has_key?('cmd')
            if shell
              cmd = ['/bin/sh', '-c', data['cmd'].join(' ')]
            else 
              cmd = data['cmd']
            end
            @client.notify('/containers/run_exec', @exec_session['id'], cmd, false)
          end
        rescue JSON::ParserError
          error "invalid json"
          @ws.close
        end
      end

      @ws.on(:close) do |event|
        @client.notify('/containers/terminate_exec', @exec_session['id'])
        @subscription.terminate if @subscription
      end
    end
  end
end