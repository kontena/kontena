module Kontena::Cli::Master
  class RemoveCommand < Kontena::Command
    include Kontena::Cli::Common

    parameter '[MASTER_NAME]', "Master name"

    banner "Note: This command only removes the master from your local configuration file"

    option '--force', :flag, "Don't ask for confirmation", attribute_name: :forced

    def run_interactive
      selections = prompt.multi_select("Select masters to remove from configuration file:") do |menu|
        config.servers.each do |server|
          menu.choice " #{pastel.green("* ") if config.current_server == server.name}#{server.name} (#{server.username || 'unknown'} @ #{server.url})", server
        end
      end
      if selections.empty?
        puts "No masters selected"
        exit 0
      end
      delete_servers(selections)
    end

    def delete_servers(servers)
      abort "Master not found in configuration" if servers.empty?

      unless forced?
        puts "Removing #{servers.size} master#{"s" if servers.size > 1} from configuration"
        confirm
      end

      config.servers.delete_if {|s| servers.include?(s) }

      unless config.find_server(config.current_server)
        puts
        puts "Current master was removed, to select a new current master use:"
        puts "  " + pastel.green.on_black("  kontena master use <master_name>  ")
        puts "Or log into another master by using:"
        puts "  " + pastel.green.on_black("  kontena master login <master_url>  ")
        config.current_server = nil
      end

      config.write
    end

    def execute
      if self.name.nil?
        run_interactive
      else
        delete_servers(config.servers.select {|s| s.name == self.name})
      end
    end
  end
end

