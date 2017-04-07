
module Kontena::Cli::Volumes
  class ShowCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    banner "Show details of a volume"

    parameter 'VOLUME', 'Volume'

    requires_current_master
    requires_current_master_token

    def execute
      vol = client.get("volumes/#{current_grid}/#{volume}")
      puts "#{vol['name']}:"
      puts "  id: #{vol['id']}"
      puts "  created: #{vol['created_at']}"
      puts "  scope: #{vol['scope']}"
      puts "  driver: #{vol['driver']}"
      puts "  driver_opts:"
      vol['driver_opts'].each do |k,v|
        puts "    #{k}: #{v}"
      end
      puts "  instances:"
      vol['instances'].each do |instance|
        puts "    - name: #{instance['name']}"
        puts "      node: #{instance['node']}"
      end
      puts "  services:"
      vol['services'].each do |service|
        puts "    - #{service['id']}"
      end

    end

  end
end
