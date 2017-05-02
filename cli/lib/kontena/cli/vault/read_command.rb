module Kontena::Cli::Vault
  class ReadCommand < Kontena::Command
    include Kontena::Cli::GridOptions

    parameter "NAME", "Secret name"

    option '--value', :flag, 'Just output the value'
    option '--return', :flag, 'Return the value', hidden: true

    def execute
      require_api_url
      require_current_grid

      token = require_token
      result = client(token).get("secrets/#{current_grid}/#{name}")
      return result['value'] if self.return?
      if self.value?
        puts result['value']
      else
        puts "#{result['name']}:"
        puts "  created_at: #{result['created_at']}"
        puts "  value: #{result['value']}"
      end
    end
  end
end
