module Kontena
  module Cli
    module GridOptions

      def self.included(base)
        if base.respond_to?(:option)
          base.option '--grid', 'GRID', 'Specify grid to use'
        end
      end
    end
  end
end
