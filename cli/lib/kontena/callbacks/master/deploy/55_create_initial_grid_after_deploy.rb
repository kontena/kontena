module Kontena
  module Callbacks
    # Runs kontena master auth-provider config after deployment if
    # auth provider configuration options have been supplied.
    #
    # Runs the config command with --preset kontena if the user has
    # authenticated to Kontena unless --no-auth-config is used.
    class CreateInitialGridAfterDeploy < Kontena::Callback

      include Kontena::Cli::Common

      matches_commands 'master create'

      def after
        return unless command.exit_code == 0
        return unless config.current_master
        return unless config.current_master.name == command.result[:name]

        cmd = "grid create --silent test"
        ENV["DEBUG"] && puts("Running: #{cmd}")
      
        spinner "Creating initial grid 'test'" do
          Kontena.run(cmd)
        end

        spinner "Selecting 'test' as current grid" do
          Kontena.run("grid use test")
        end
      end
    end
  end
end
