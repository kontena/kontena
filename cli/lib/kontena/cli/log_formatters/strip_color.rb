require 'logger'

module Kontena
  module Cli
    module LogFormatter
      class StripColor < Logger::Formatter
        def msg2str(msg)
          super(msg.kind_of?(String) ? msg.gsub(/\e+\[{1,2}[0-9;:?]+m/m, '') : msg)
        end
      end
    end
  end
end
