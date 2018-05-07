module Kontena::Cli::Stacks::Labels
  module Common
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