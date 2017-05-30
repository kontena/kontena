module Kontena::Cli::Stacks
  module YAML
    class Opto::Setters::Vault < ::Opto::Setter
      include Kontena::Cli::Common
      def set(value)
        if current_master && current_grid
          client.put("secrets/#{current_grid}/#{hint}", {name: hint, value: value, upsert: true})
        end
      end
    end
  end
end
