module Docker
  class StreamingExecutor

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
            cmd = JSON.parse(event.data)
            cmd = ['/bin/sh', '-c', cmd.join(' ')] if shell
            @client.notify('/containers/run_exec', @exec_session['id'], cmd, true)
            init = false
          rescue JSON::ParserError
            @ws.close
          end
        else
          @client.notify('/containers/tty_input', @exec_session['id'], event.data)
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
          cmd = JSON.parse(event.data)
          cmd = ['/bin/sh', '-c', cmd.join(' ')] if shell
          @client.notify('/containers/run_exec', @exec_session['id'], cmd, false)
        rescue JSON::ParserError
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