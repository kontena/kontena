require 'io/console'
require 'kontena-websocket-client'

module Kontena::Cli::Helpers
  module ExecHelper

    websocket_log_level = if ENV["DEBUG"] == 'websocket'
      Logger::DEBUG
    elsif ENV["DEBUG"]
      Logger::INFO
    else
      Logger::WARN
    end

    Kontena::Websocket::Logging.initialize_logger(STDERR, websocket_log_level)

    # @param ws [Kontena::Websocket::Client]
    # @param tty [Boolean] read stdin in raw mode, sending tty escapes for remote pty
    # @raise [ArgumentError] not a tty
    # @yield [data]
    # @yieldparam data [String, nil] nil on EOF
    # @raise [ArgumentError] not a tty
    # @return [Thread]
    def read_stdin(tty: nil)
      raise ArgumentError, "the input device is not a TTY" if tty && !STDIN.tty?

      if tty
        STDIN.raw {
          # XXX: raises EOF?
          while data = STDIN.readpartial(1024)
            yield data
          end
        }
      else
        while line = STDIN.gets
          yield line
        end
      end
    end

    # @return [String]
    def websocket_url(path, query)
      url = URI.parse(require_current_master.url)
      url.scheme = url.scheme.sub('http', 'ws')
      url.path = '/v1/' + path
      url.query = URI.encode_www_form(query)
      url.to_s
    end

    # @param ws [Kontena::Websocket::Client]
    # @return [Integer] exit code
    def websocket_exec_read(ws)
      ws.read do |msg|
        msg = JSON.parse(msg)

        logger.debug "websocket exec read: #{msg.inspect}"

        if msg.has_key?('exit')
          # breaks the read loop
          return msg['exit'].to_i
        elsif msg.has_key?('stream')
          if msg['stream'] == 'stdout'
            $stdout << msg['chunk']
          else
            $stderr << msg['chunk']
          end
        end
      end
    end

    # @param ws [Kontena::Websocket::Client]
    # @param msg [Hash]
    def websocket_exec_write(ws, msg)
      logger.debug "websocket exec write: #{msg.inspect}"

      ws.send(JSON.dump(msg))
    end

    # Start thread to read from stdin, and write to websocket.
    # Logs stdin read errors.
    #
    # @param ws [Kontena::Websocket::Client]
    # @param tty [Boolean]
    # @return [Thread]
    def websocket_exec_write_thread(ws, tty: nil)
      Thread.new do
        begin
          read_stdin(tty: tty) do |stdin|
            logger.debug "websocket exec write: #{stdin.inspect}"
            websocket_exec_write(ws, stdin: stdin)
          end
          websocket_exec_write(ws, stdin: nil) # EOF
        rescue => exc
          logger.error exc
        end
      end
    end

    # Connect to server websocket, send from stdin, and write out messages
    #
    # @param paths [String]
    # @param options [Hash] @see Kontena::Websocket::Client
    # @param cmd [Array<String>] command to execute
    # @param interactive [Boolean] Interactive TTY on/off
    # @param shell [Boolean] Shell on/of
    # @param tty [Boolean] TTY on/of
    # @return [Integer] exit code
    def websocket_exec(path, cmd, interactive: false, shell: false, tty: false)
      write_thread = nil

      query = {}
      query[:interactive] = interactive if interactive
      query[:shell] = shell if shell
      query[:tty] = tty if tty

      url = websocket_url(path, query)
      token = require_token
      options = {
        headers: {
          'Authorization' => "Bearer #{token.access_token}"
        },
        ssl_params: {
          verify_mode: ENV['SSL_IGNORE_ERRORS'].to_s == 'true' ? OpenSSL::SSL::VERIFY_NONE : OpenSSL::SSL::VERIFY_PEER,
        },
      }

      logger.debug { "websocket exec connect: #{url} #{options}"}

      # we do not expect CloseError, because the server will send an 'exit' message first, which causes us to exit before seeing the close frame.
      # TODO: handle HTTP 404 errors
      exit_status = Kontena::Websocket::Client.connect(url, **options) do |ws|
        # first frame contains exec command
        websocket_exec_write(ws, cmd: cmd)

        # start new thread to write from stdin to websocket
        write_thread = websocket_exec_write_thread(ws, tty: tty)

        # blocks reading from websocket, returns with exec exit code
        websocket_exec_read(ws)
      end

    rescue Kontena::Websocket::Error => exc
      logger.warn { "websocket exec error: #{exc}" }
      return 1

    rescue => exc
      logger.error { "websocket exec error: #{exc}" }
      raise

    else
      logger.debug { "websocket exec exit: #{exit_status}"}
      return exit_status

    ensure
      write_thread.kill if write_thread
    end

    # Execute command on container using websocket API.
    #
    # @param grid [String] Grid ID
    # @param id [String] Container ID (host/name)
    # @param cmd [Array<String>] command to execute
    # @return [Integer] exit code
    def container_exec(grid, id, cmd, **exec_options)
      websocket_exec("containers/#{grid}/#{id}/exec", cmd, **exec_options)
    end
  end
end
