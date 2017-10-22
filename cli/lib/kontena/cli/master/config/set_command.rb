module Kontena::Cli::Master::Config
  class SetCommand < Kontena::Command

    requires_current_master
    requires_current_master_token

    banner "Sets a configuration value to Master"

    parameter "KEY_VALUE_PAIR ...", "Key/value pair, for example server.root_url=http://example.com", required: true

    def execute
      data = self.key_value_pair_list.map{ |p| p.split('=') }.to_h
      client.patch('config', data)
    end
  end
end

