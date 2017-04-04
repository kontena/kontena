module Kontena::Cli::Stacks::YAML::Opto::Resolvers
  class VaultCertPrompt < ::Opto::Resolver
    include Kontena::Cli::Common

    def resolve
      return nil unless current_master && current_grid
      message = hint || 'Select SSL certs'
      secrets = get_secrets.select{ |s|
        s['name'].match(/(ssl|cert)/i)
      }
      if secrets.size > 0
        prompt.multi_select(hint) do |menu|
          menu.default(*default_indexes(secrets)) if option.default
          secrets.each do |s|
            menu.choice s['name']
          end
        end
      end
    end

    # @return [Array<Hash>] secrets
    def get_secrets
      client.get("grids/#{current_grid}/secrets")['secrets']
    rescue
      []
    end

    # @param [Array<Hash>] secrets
    # @return [Array<Integer>]
    def default_indexes(secrets)
      indexes = []
      option.default.to_a.each do |name|
        index = secrets.index { |s| s['name'] == name }
        indexes << index.to_i + 1 if index
      end
      indexes
    end
  end
end
