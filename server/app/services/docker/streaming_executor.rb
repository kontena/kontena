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
    def start_tty
      create_session
      subscribe_to_session
      register_tty_ws_events
    end

    # Starts normal exec session (without tty)
    def start 
      create_session
      subscribe_to_session
      register_run_ws_events
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

    def register_tty_ws_events
      init = true
      @ws.on(:message) do |event|
        if init == true
          cmd = ['/bin/sh', '-c', event.data]
          @client.notify('/containers/tty_exec', @exec_session['id'], cmd)
          init = false
        else
          @client.notify('/containers/tty_input', @exec_session['id'], event.data)
        end
      end

      @ws.on(:close) do |event|
        @client.notify('/containers/terminate_exec', @exec_session['id'])
        @subscription.terminate if @subscription
      end
    end

    def register_run_ws_events
      @ws.on(:message) do |event|
        @client.notify('/containers/run_exec', @exec_session['id'], event.data)
      end

      @ws.on(:close) do |event|
        @client.notify('/containers/terminate_exec', @exec_session['id'])
        @subscription.terminate if @subscription
      end
    end
  end
end