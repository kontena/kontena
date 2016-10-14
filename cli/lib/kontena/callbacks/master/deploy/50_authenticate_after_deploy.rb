
module Kontena
  module Callbacks
    class AuthenticateAfterDeploy < Kontena::Callback

      include Kontena::Cli::Common

      matches_commands 'master create'

      def after
        ENV["DEBUG"] && puts("Command result: #{command.result.inspect}")
        ENV["DEBUG"] && puts("Command exit code: #{command.exit_code.inspect}")
        return unless command.exit_code == 0
        return unless command.result.kind_of?(Hash)
        return unless command.result.has_key?(:public_ip)
        return unless command.result.has_key?(:code)
        return unless command.result.has_key?(:name)

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
          ENV["DEBUG"] && puts("Trying to request / from #{new_master.url}")
          client = Kontena::Client.new(new_master.url, nil, ignore_ssl_errors: true)
          client.get('/')
        rescue 
          ENV["DEBUG"] && puts("HTTPS test failed: #{$!} #{$!.message}")
          unless retried
            new_master.url = "http://#{command.result[:public_ip]}"
            retried = true
            retry
          end
          return
        end

        require 'shellwords'
        cmd = "master login --no-login-info --skip-grid-auto-select --verbose --name #{command.result[:name].shellescape} --code #{command.result[:code].shellescape} #{new_master.url.shellescape}"
        ENV["DEBUG"] && puts("Running: #{cmd}")
        Kontena.run(cmd)
      end
    end
  end
end
