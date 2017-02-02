module Kontena::Cli::Stacks
  module YAML
    class Opto::Resolvers::VaultCertPrompt < Opto::Resolver
      include Kontena::Cli::Common

      def resolve
        message = hint || 'Select SSL certs'
        secrets = client.get("grids/#{current_grid}/secrets")['secrets'].select{ |s|
          s['name'].match(/(ssl|cert)/i)
        }
        prompt.multi_select(hint, secrets.map{ |s| s['name'] })
      end
    end
  end
end
