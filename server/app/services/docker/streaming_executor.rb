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

    # Starts normal exec session (without tty)
    # @param [Boolean] shell
    # @param [Boolean] stdin
    # @param [Boolean] tty
    def start(shell, stdin, tty)
      create_session
      subscribe_to_session
      if stdin
        register_stdin_ws_events(shell, tty)
      else
        register_run_ws_events(shell, tty)
      end
    end

    def create_session
      @exec_session = @client.request('/containers/create_exec', @container.container_id)
    end

    def subscribe_to_session
      @subscription = MongoPubsub.subscribe("container_exec:#{@exec_session['id']}") do |data|
        if data.has_key?('error')
          @ws.send(JSON.dump({ error: data['error'] }))
          @ws.close(4000)
        elsif data.has_key?('exit')
          @ws.send(JSON.dump({ exit: data['exit'] }))
          @ws.close(1000)
        else
          @ws.send(JSON.dump({ stream: data['stream'], chunk: data['chunk'] }))
        end
      end
    end

    # @param [Boolean] shell
    # @param [Boolean] tty
    def register_stdin_ws_events(shell, tty)
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
              @client.notify('/containers/run_exec', @exec_session['id'], cmd, tty, true)
              init = false
            end
          rescue JSON::ParserError
            error "invalid handshake json"
            @ws.close
          end
        else
          begin
            input = JSON.parse(event.data)
            if input.has_key?('stdin')
              @client.notify('/containers/tty_input', @exec_session['id'], input['stdin'])
            elsif input.has_key?('tty_size')
              @client.notify('/containers/tty_resize', @exec_session['id'], input['tty_size'])
            end
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
    # @param [Boolean] tty
    def register_run_ws_events(shell, tty)
      @ws.on(:message) do |event|
        begin
          data = JSON.parse(event.data)
          if data.has_key?('cmd')
            if shell
              cmd = ['/bin/sh', '-c', data['cmd'].join(' ')]
            else
              cmd = data['cmd']
            end
            @client.notify('/containers/run_exec', @exec_session['id'], cmd, tty, false)
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