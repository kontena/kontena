module Kontena
  module Callbacks
    class OptionPlacement < Kontena::Callback
      matches_commands '* exec', '* ssh'

      def before_parse
        Clamp.allow_options_after_parameters = false
        true
      end

      def after
        Clamp.allow_options_after_parameters = true
      end
    end
  end
end
