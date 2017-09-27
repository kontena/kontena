require_relative '../services/services_helper'

module Kontena::Cli::Certificate
  class RemoveCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    parameter "SUBJECT", "Certificate subject"
    option "--force", :flag, "Force remove", default: false, attribute_name: :forced

    requires_current_master
    requires_current_master_token
    requires_current_grid

    def execute
      confirm_command(self.subject) unless forced?

      spinner "Removing certificate for #{self.subject.colorize(:cyan)} from #{current_grid.colorize(:cyan)} grid " do
        client.delete("certificates/#{current_grid}/#{self.subject}")
      end
    end
  end
end
