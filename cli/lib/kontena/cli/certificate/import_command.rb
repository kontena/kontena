module Kontena::Cli::Certificate
  class ImportCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    parameter 'CERT_FILE', "Path to PEM-encodede X.509 certificate file"
    option ['--private-key', '--key'], 'KEY_FILE', "Path to private key file", :required => true, :attribute_name => :key_file
    option ['--chain'], 'CHAIN_FILE', "Path to CA cert chain file", :multivalued => true, :attribute_name => :chain_file_list

    requires_current_master
    requires_current_master_token
    requires_current_grid

    def execute
      certificate = spinner "Importing certificate from #{cert_file}..." do
        client.post("grids/#{current_grid}/certificates",
          certificate: File.read(self.cert_file),
          private_key: File.read(self.key_file),
          chain: chain_file_list.map{|chain_file| File.read(chain_file)},
        )
      end

      puts YAML.dump(certificate)
    end
  end
end
