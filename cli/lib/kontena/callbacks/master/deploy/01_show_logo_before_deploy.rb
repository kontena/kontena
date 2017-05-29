module Kontena
  module Callbacks
    class DisplayLogoBeforeMasterDeploy < Kontena::Callback

      matches_commands 'master create'

      def before
        extend Kontena::Cli::Common
        display_logo
      end
    end
  end
end

