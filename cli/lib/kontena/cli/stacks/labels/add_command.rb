require_relative '../common'

module Kontena::Cli::Stacks::Labels
  class AddCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    parameter "NAME", "Stack name"
    parameter "LABEL ...", "Labels"

    requires_current_master
    requires_current_master_token

    def execute
      original_labels = fetch_master_data(name)
      update_stack(name, { 'labels' => (original_labels + label_list).uniq })
    end

    private

    def update_stack(name, data)
      client.patch(stack_url(name), data)
    end

    def stack_url(name)
      "stacks/#{current_grid}/#{name}"
    end

    def fetch_master_data(stackname)
      original_data = client.get(stack_url(stackname))
      # ensure we always return either labels or an empty array
      original_data['labels'] || []
    end
  end
end