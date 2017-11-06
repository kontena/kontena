module Kontena::Cli::Certificate
  class ImportCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    # @raise [ArgumentError]
    def open_file(path)
      File.open(path)
    rescue Errno::ENOENT
      raise ArgumentError, "File not found: #{path}"
    end

    parameter 'CERT_FILE', "Path to PEM-encodede X.509 certificate file" do |path|
      open_file(path)
    end
    option ['--private-key', '--key'], 'KEY_FILE', "Path to private key file", :required => true, :attribute_name => :key_file do |path|
      open_file(path)
    end
    option ['--chain'], 'CHAIN_FILE', "Path to CA cert chain file", :multivalued => true, :attribute_name => :chain_file_list do |path|
      open_file(path)
    end

    requires_current_master
    requires_current_master_token
    requires_current_grid

    def execute
      certificate = spinner "Importing certificate from #{cert_file}..." do
        client.post("grids/#{current_grid}/certificates",
          certificate: self.cert_file.read(),
          private_key: self.key_file.read(),
          chain: chain_file_list.map{|chain_file| chain_file.read() },
        )
      end

      puts YAML.dump(certificate)
    end
  end
end
