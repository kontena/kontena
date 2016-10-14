module Kontena
  module Cli
    module GridOptions

      def self.included(base)
        if base.respond_to?(:option)
          base.option '--grid', 'GRID', 'Specify grid to use', environment_variable: 'KONTENA_GRID'
          base.requires_current_grid if base.respond_to?(:requires_current_grid)
        end
      end
    end
  end
end
