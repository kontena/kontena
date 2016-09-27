module Kontena
  module Callbacks
    class DefaultMasterVersion < Kontena::Callback

      matches_commands 'master create'

      def after_load
        # Only run this for prerelease cli
        return unless Kontena::Cli::VERSION =~ /\d\.(?:pre|rc|beta|edge)/
        version_switch = command.recognised_options.find {|opt| opt.switches.include?('--version')}
        if version_switch
          version_switch.instance_variable_set(:@default_value, 'edge')
        end
      end
    end
  end
end

