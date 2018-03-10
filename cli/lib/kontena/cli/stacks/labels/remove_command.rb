require_relative '../common'
require_relative 'common'

module Kontena::Cli::Stacks::Labels
  class RemoveCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Common

    parameter "NAME", "Stack name"
    parameter "LABEL ...", "Labels"

    requires_current_master
    requires_current_master_token

    def execute
      original_labels = fetch_master_data(name)
      update_stack(name, { 'labels' => (original_labels - label_list) })
    end
  end
end