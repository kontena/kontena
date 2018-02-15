
module Kontena::Cli::Volumes
  class RemoveCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions


    banner "Removes a volume"
    parameter 'VOLUME ...', 'Volume name', attribute_name: :volumes
    option "--force", :flag, "Force remove", default: false, attribute_name: :forced

    requires_current_master
    requires_current_master_token

    def execute
      volumes.each do |volume|
        confirm_command(volume) unless forced?

        spinner "Removing volume #{pastel.cyan(volume)} " do
          remove_volume(volume)
        end
      end
    end

    def remove_volume(volume)
      client.delete("volumes/#{current_grid}/#{volume}")
    end
  end
end
