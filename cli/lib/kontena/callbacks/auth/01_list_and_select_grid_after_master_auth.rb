module Kontena
  module Callbacks
    class ListAndSelectGrid < Kontena::Callback

      include Kontena::Cli::Common

      matches_commands 'master login'

      def after_load
        command.class_eval do
          option ['--skip-grid-auto-select'], :flag, 'Do not auto select grid'
        end
      end

      # Runs kontena grids list --use which will auto join the first available
      # grid
      def after
        return if command.skip_grid_auto_select?
        return unless current_master
        return unless command.exit_code == 0
        return unless current_master.grid.nil?

        Kontena.run(%w(grid list --use --verbose), returning: :status)
      end
    end
  end
end
