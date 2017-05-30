module Kontena::Cli::Stacks
  module YAML
    class Opto::Resolvers::Vault < ::Opto::Resolver
      include Kontena::Cli::Common
      def resolve
        raise RuntimeError, "Missing or empty vault secret name" if hint.to_s.empty?
        if current_master && current_grid
          client.get("secrets/#{current_grid}/#{hint}")['value'] rescue nil
        end
      end
    end
  end
end
