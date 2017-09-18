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

    WEBSOCKET_CLIENT_OPTIONS = {
      connect_timeout: ENV["EXCON_CONNECT_TIMEOUT"] ? ENV["EXCON_CONNECT_TIMEOUT"].to_f : 10.0,
      open_timeout:    ENV["EXCON_CONNECT_TIMEOUT"] ? ENV["EXCON_CONNECT_TIMEOUT"].to_f : 10.0,
      ping_interval:   ENV["EXCON_READ_TIMEOUT"]    ? ENV["EXCON_READ_TIMEOUT"].to_f    : 30.0,
      ping_timeout:    ENV["EXCON_CONNECT_TIMEOUT"] ? ENV["EXCON_CONNECT_TIMEOUT"].to_f : 10.0,
      close_timeout:   ENV["EXCON_CONNECT_TIMEOUT"] ? ENV["EXCON_CONNECT_TIMEOUT"].to_f : 10.0,
      write_timeout:   ENV["EXCON_WRITE_TIMEOUT"]   ? ENV["EXCON_WRITE_TIMEOUT"].to_f   : 10.0,
    }

    # @param ws [Kontena::Websocket::Client]
    # @param tty [Boolean] read stdin in raw mode, sending tty escapes for remote pty
    # @raise [ArgumentError] not a tty
    # @yield [data]
    # @yieldparam data [String] data from stdin
    # @raise [ArgumentError] not a tty
    # @return EOF on stdin (!tty)
    def read_stdin(tty: nil)
      if tty
        raise ArgumentError, "the input device is not a TTY" unless STDIN.tty?

        STDIN.raw { |io|
          # we do not expect EOF on a TTY, ^D sends a tty escape to close the pty instead
          loop do
            # raises EOFError, SyscallError or IOError
            yield io.readpartial(1024)
          end
        }
      else
        # line-buffered
        while line = STDIN.gets
          yield line
        end
      end
    end

    # @return [String]
    def websocket_url(path, query = nil)
      url = URI.parse(require_current_master.url)
      url.scheme = url.scheme.sub('http', 'ws')
      url.path = '/v1/' + path
      url.query = (query && !query.empty?) ? URI.encode_www_form(query) : nil
      url.to_s
    end

    # @param ws [Kontena::Websocket::Client]
    # @raise [RuntimeError] exec error
    # @return [Integer] exit code
    def websocket_exec_read(ws)
      ws.read do |msg|
        msg = JSON.parse(msg)

        logger.debug "websocket exec read: #{msg.inspect}"

        if msg.has_key?('error')
          raise msg['error']
        elsif msg.has_key?('exit')
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
    # Closes websocket on stdin read errors.
    #
    # @param ws [Kontena::Websocket::Client]
    # @param tty [Boolean]
    # @return [Thread]
    def websocket_exec_write_thread(ws, tty: nil)
      Thread.new do
        begin
          if tty
            console_height, console_width = IO.console.winsize
            websocket_exec_write(ws, 'tty_size' => {
              width: console_width, height: console_height
            })
          end
          read_stdin(tty: tty) do |stdin|
            websocket_exec_write(ws, 'stdin' => stdin)
          end
          websocket_exec_write(ws, 'stdin' => nil) # EOF
        rescue => exc
          logger.error exc
          ws.close(1001, "stdin read #{exc.class}: #{exc}")
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
      exit_status = nil
      write_thread = nil

      query = {}
      query[:interactive] = interactive if interactive
      query[:shell] = shell if shell
      query[:tty] = tty if tty

      server = require_current_master
      url = websocket_url(path, query)
      token = require_token
      options = WEBSOCKET_CLIENT_OPTIONS.dup
      options[:headers] = {
          'Authorization' => "Bearer #{token.access_token}"
      }
      options[:ssl_params] = {
          verify_mode: ENV['SSL_IGNORE_ERRORS'].to_s == 'true' ? OpenSSL::SSL::VERIFY_NONE : OpenSSL::SSL::VERIFY_PEER,
          ca_file: server.ssl_cert_path,
      }
      options[:ssl_hostname] = server.ssl_subject_cn

      logger.debug { "websocket exec connect... #{url}" }

      # we do not expect CloseError, because the server will send an 'exit' message first,
      # and we return before seeing the close frame
      # TODO: handle HTTP 404 errors
      Kontena::Websocket::Client.connect(url, **options) do |ws|
        logger.debug { "websocket exec open" }

        # first frame contains exec command
        websocket_exec_write(ws, 'cmd' => cmd)

        if interactive
          # start new thread to write from stdin to websocket
          write_thread = websocket_exec_write_thread(ws, tty: tty)
        end

        # blocks reading from websocket, returns with exec exit code
        exit_status = websocket_exec_read(ws)

        fail ws.close_reason unless exit_status
      end

    rescue Kontena::Websocket::Error => exc
      exit_with_error(exc)

    rescue => exc
      logger.error { "websocket exec error: #{exc}" }
      raise

    else
      logger.debug { "websocket exec exit: #{exit_status}"}
      return exit_status

    ensure
      if write_thread
        write_thread.kill
        write_thread.join
      end
    end

    # Execute command on container using websocket API.
    #
    # @param id [String] Container ID (grid/host/name)
    # @param cmd [Array<String>] command to execute
    # @return [Integer] exit code
    def container_exec(id, cmd, **exec_options)
      websocket_exec("containers/#{id}/exec", cmd, **exec_options)
    end
  end
end
