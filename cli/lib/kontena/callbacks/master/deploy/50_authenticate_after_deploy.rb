
module Kontena
  module Callbacks
    class AuthenticateAfterDeploy < Kontena::Callback

      include Kontena::Cli::Common

      matches_commands 'master create'

      def after
        ENV["DEBUG"] && $stderr.puts("Command result: #{command.result.inspect}")
        ENV["DEBUG"] && $stderr.puts("Command exit code: #{command.exit_code.inspect}")
        return unless command.exit_code == 0
        return unless command.result.kind_of?(Hash)
        return unless command.result.has_key?(:public_ip)
        return unless command.result.has_key?(:code)
        return unless command.result.has_key?(:name)

        # If plugins generate self-signed cert, most of the upcoming callbacks will
        # fail without this. This can be made bit more clever once all the plugins
        # return the generated self-signed certificate.
        ENV['SSL_IGNORE_ERRORS'] = 'true'

        # In case there already is a server with the same name add random characters to name
        if config.find_server(command.result[:name])
          command.result[:name] = "#{command.result[:name]}-#{SecureRandom.hex(2)}"
        end

        new_master = Kontena::Cli::Config::Server.new(
          url: "https://#{command.result[:public_ip]}",
          name: command.result[:name]
        )

        retried = false

        # Figure out if HTTPS works, if not, try HTTP
        begin
          ENV["DEBUG"] && $stderr.puts("Trying to request / from #{new_master.url}")
          client = Kontena::Client.new(new_master.url, nil, ignore_ssl_errors: true)
          client.get('/')
        rescue => ex
          ENV["DEBUG"] && $stderr.puts("HTTPS test failed: #{ex.class.name} #{ex.message}")
          unless retried
            new_master.url = "http://#{command.result[:public_ip]}"
            retried = true
            retry
          end
          return
        end

        require 'shellwords'
        cmd = "master login --no-login-info --skip-grid-auto-select --verbose --name #{command.result[:name].shellescape} --code #{command.result[:code].shellescape} #{new_master.url.shellescape}"
        Retriable.retriable do
          ENV["DEBUG"] && $stderr.puts("Running: #{cmd}")
          Kontena.run(cmd)
        end
      end
    end
  end
end
