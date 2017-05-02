module Kontena::Cli::Master::Config
  class UnsetCommand < Kontena::Command

    requires_current_master
    requires_current_master_token

    parameter "KEY ...", "Key(s) to unset", required: true

    banner "Clears a configuration value from Master"

    def execute
      self.key_list.each do |key|
        client.delete("config/#{key}")
      end
    end
  end
end

