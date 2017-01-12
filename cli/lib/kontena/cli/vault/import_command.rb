module Kontena::Cli::Vault
  class ImportCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    option ['-u', '--upsert'], :flag, 'Create secret unless already exists', default: false
    parameter "FILENAME", "Secret yaml file"

    def execute
      require_api_url
      require_current_grid
      token = require_token

      # Not sure of a better way to do this for now. Skips the first two ARGF
      # reads in order to get to the third without raising an error.
      2.times do
        begin
          ARGF.read
        rescue
        end
      end

      raw = ARGF.read
      exit_with_error('No data recieved from yaml file') if raw.to_s == ''
      begin
        secrets = YAML.load(raw)
      rescue
        exit_with_error('STDIN did not contain valid yaml')
      end

      current_secret_keys =
        client(token)
        .get("grids/#{current_grid}/secrets")
        .fetch('secrets')
        .map { |entry| entry.fetch('name') }

      count = 0 
      vspinner 'Importing all values into the vault' do
        secrets.each_pair do |name, secret|
          data = {
            name: name,
            value: secret,
            upsert: upsert?
          }
          if current_secret_keys.include?(name) && upsert?
            client(token).put("secrets/#{current_grid}/#{name}", data)
            count = count+1
          elsif !current_secret_keys.include?(name)
            client(token).post("grids/#{current_grid}/secrets", data)
            count = count+1
          end
        end
      end
      
      puts "Imported #{count} secrets."
    end
  end
end
