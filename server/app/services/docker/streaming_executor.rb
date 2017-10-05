module Docker
  class StreamingExecutor
    include Logging

    # @param [Container] container
    # @param [Boolean] shell
    # @param [Boolean] stdin
    # @param [Boolean] tty
    def initialize(container, shell: false, interactive: false, tty: false)
      @container = container
      @shell = shell
      @interactive = interactive
      @tty = tty

      @rpc_client = container.host_node.rpc_client

      @exec_session = nil
      @subscription = nil
      @started = false
    end

    # @return [Boolean]
    def interactive?
      !!@interactive
    end

    def started!
      @started = true
    end

    # start() was successful
    # @return [Boolean]
    def started?
      @started
    end

    def running!
      @running = true
    end

    # exec is running, and ready to accept input/tty_resize
    #
    # @return [Boolean]
    def running?
      @running
    end

    # Valid after setup()

    # @return [String] container exec RPC UUID
    def exec_id
      @exec_session['id']
    end

    # Setup RPC state
    def setup
      @exec_session = exec_create
      @subscription = subscribe_to_exec(@exec_session['id'])
    end

    # @return [Hash{:id => String}]
    def exec_create
      @rpc_client.request('/containers/create_exec', @container.container_id).tap do |session|
        debug { "exec create: #{session.inspect}" }
      end
    end

    # @param cmd [Array<String>]
    # @param tty [Boolean]
    # @param stdin [Boolean]
    def exec_run(cmd, shell: false, tty: false, stdin: false)
      if shell
        cmd = ['/bin/sh', '-c', cmd.join(' ')]
      end

      debug { "exec #{self.exec_id} run with shell=#{shell} tty=#{tty} stdin=#{stdin}: #{cmd.inspect}" }

      @rpc_client.notify('/containers/run_exec', self.exec_id, cmd, tty, stdin)
    end

    # @param tty_size [Hash{'width' => Integer, 'height' => Integer}]
    def exec_resize(tty_size)
      debug { "exec #{self.exec_id} resize: #{tty_size.inspect}" }

      @rpc_client.notify('/containers/tty_resize', self.exec_id, tty_size)
    end

    # @param stdin [String]
    def exec_input(stdin)
      debug { "exec #{self.exec_id} input: #{stdin.inspect}" }

      @rpc_client.notify('/containers/tty_input', self.exec_id, stdin)
    end

    def exec_terminate
      debug { "exec #{self.exec_id} terminate" }

      @rpc_client.notify('/containers/terminate_exec', self.exec_id)
    end

    # @return [MongoPubsub::Subscription]
    def subscribe_to_exec(id)
      MongoPubsub.subscribe("container_exec:#{id}") do |data|
        debug { "subscribe exec #{id}: #{data.inspect}" }

        if data.has_key?('error')
          websocket_write(error: data['error'])
          websocket_close(4000)
        elsif data.has_key?('exit')
          websocket_write(exit: data['exit'])
          websocket_close(1000)
        elsif data.has_key?('stream')
          websocket_write(stream: data['stream'], chunk: data['chunk'])
        else
          error "invalid container exec #{channel} RPC: #{data.inspect}"
        end
      end
    end

    # Does not raise.
    #
    # @param ws [Faye::Websocket]
    def start(ws)
      @ws = ws

      @ws.on(:message) do |event|
        on_websocket_message(event.data)
      end

      @ws.on(:close) do |event|
        on_websocket_close(event.code, event.reason)
      end

      started!
    end

    # @param data [Hash] Write websocket JSON frame
    def websocket_write(data)
      debug { "websocket write: #{data.inspect}" }

      msg = JSON.dump(data)

      EventMachine.schedule {
        @ws.send(msg)
      }
    end

    # @param code [Integer]
    # @param reason [String]
    def websocket_close(code, reason = nil)
      debug { "websocket close with code #{code}: #{reason}"}

      EventMachine.schedule {
        @ws.close(code, reason)
      }
    end

    def on_websocket_message(msg)
      data = JSON.parse(msg)

      debug { "websocket message: #{data.inspect}"}

      if data.has_key?('cmd')
        fail "already running" if running?
        exec_run(data['cmd'], shell: @shell, tty: @tty, stdin: @interactive)
        running!
      end

      if data.has_key?('stdin')
        fail "not running" unless running?
        exec_input(data['stdin'])
      end

      if data.has_key?('tty_size')
        fail "not running" unless running?
        exec_resize(data['tty_size'])
      end
    rescue JSON::ParserError => exc
      warn "invalid websocket JSON: #{exc}"
      abort exc
    rescue => exc
      error exc
      abort exc
    end

    # @param code [Integer]
    # @param reason [String]
    def on_websocket_close(code, reason)
      debug "websocket closed with code #{code}: #{reason}"

      self.teardown
    end

    # Abort exec on error.
    #
    # Closes client websocket, terminates the exec RPC.
    #
    # @param exc [Exception]
    def abort(exc)
      websocket_close(4000, "#{exc.class}: #{exc}")
      self.teardown
    end

    # Release resources from #setup()
    #
    # Can be called multiple times (abort -> on_websocket_close)
    def teardown
      if @subscription
        @subscription.terminate
        @subscription = nil
      end

      if @exec_session
        exec_terminate
        @exec_session = nil
      end
    end
  end
end
