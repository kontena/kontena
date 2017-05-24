module Kontena::Cli::Master::Config
  class UnsetCommand < Kontena::Command

    include Kontena::Cli::Common

    requires_current_master
    requires_current_master_token

    parameter "CONFIG_KEY ...", "Key(s) to unset", required: true, attribute_name: :key_list

    banner "Clears a configuration value from Master"

    def execute
      self.key_list.each do |key|
        client.delete("config/#{key}")
      end
    end
  end
end

