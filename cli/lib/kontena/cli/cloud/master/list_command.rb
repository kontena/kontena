module Kontena::Cli::Cloud::Master
  class ListCommand < Kontena::Command

    include Kontena::Cli::Common

    callback_matcher 'cloud-master', 'list'

    requires_current_account_token

    def execute
      response = cloud_client.get('user/masters')
      unless response && response.kind_of?(Hash) && response['data'].kind_of?(Array)
        puts "Listing masters failed".colorize(:red)
        exit 1
      end

      if response['data'].empty?
        puts "No masters registered"
      else
        puts '%-26.26s %-24s %-12s %s' % ['ID', 'NAME', 'OWNER', 'URL']
        response['data'].each do |data|
          attr = data['attributes']
          puts '%-26.26s %-24s %-12s %s' % [data['id'], attr['name'], attr['owner'], attr['url']]
        end
      end
    end
  end
end

