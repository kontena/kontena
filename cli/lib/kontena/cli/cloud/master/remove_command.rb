module Kontena::Cli::Cloud::Master
  class RemoveCommand < Kontena::Command

    include Kontena::Cli::Common

    callback_matcher 'cloud-master', 'delete'

    requires_current_account_token

    parameter "[MASTER_ID]", "Master ID"

    option ['-f', '--force'], :flag, "Don't ask for confirmation"

    def delete_server(id)
      spinner "Deleting server #{id} from Kontena Cloud" do |spin|
        begin
          cloud_client.delete("user/masters/#{id}")
        rescue
          spin.fail
        end
      end
    end

    def run_interactive
      response = nil
      spinner "Retrieving a list of registered masters on Kontena Cloud" do
        response = cloud_client.get('user/masters')
        unless response && response.kind_of?(Hash) && response['data'].kind_of?(Array)
          abort pastel.red('Listing masters failed')
        end
      end

      if response['data'].empty?
        puts "No registered masters"
        return
      end

      servers_to_delete = prompt.multi_select("Select registered master(s) to delete:") do |menu|
        response['data'].each do |server|
          menu.choice "#{server['attributes']['name']} (#{server['attributes']['url'] || "?"})", server['id']
        end
      end

      if servers_to_delete.empty?
        puts "No masters selected"
      else
        puts "About to delete servers from Kontena Cloud:"
        servers_to_delete.each do |id|
          puts " * #{id}"
        end
        confirm unless self.force?
        servers_to_delete.each do |id|
          delete_server(id)
        end
      end
    end

    def execute
      if self.master_id.nil?
        run_interactive
      else
        confirm unless self.force?
        delete_server(self.master_id)
      end
      exit 0
    end
  end
end
