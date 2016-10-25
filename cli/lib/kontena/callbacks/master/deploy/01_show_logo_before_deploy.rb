module Kontena
  module Callbacks
    class DisplayLogoBeforeMasterDeploy < Kontena::Callback

      include Kontena::Cli::Common

      matches_commands 'master create'

      def before
        display_logo
      end
    end
  end
end

