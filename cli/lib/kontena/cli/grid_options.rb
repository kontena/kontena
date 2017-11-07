module Kontena
  module Cli
    module GridOptions

      def self.included(base)
        if base.respond_to?(:option)
          base.option '--grid', 'GRID', 'Specify grid to use'
          base.option '--master', 'MASTER_NAME', 'Specify Kontena Master to use' do |master_name|
            config.current_master = master_name
          end
        end
      end
    end
  end
end
