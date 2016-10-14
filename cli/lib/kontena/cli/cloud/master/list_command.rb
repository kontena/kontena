module Kontena::Cli::Cloud::Master
  class ListCommand < Kontena::Command

    include Kontena::Cli::Common

    callback_matcher 'cloud-master', 'list'

    option '--return', :flag, 'Return the list', hidden: true

    requires_current_account_token

    def execute
      response = cloud_client.get('user/masters')
      unless response && response.kind_of?(Hash) && response['data'].kind_of?(Array)
        abort "Listing masters failed".colorize(:red)
      end

      if response['data'].empty?
        return [] if self.return?
        puts "No masters registered"
      else
        return response['data'] if self.return?
        puts '%-26.26s %-24s %-12s %s' % ['ID', 'NAME', 'OWNER', 'URL']
        response['data'].each do |data|
          attr = data['attributes']
          puts '%-26.26s %-24s %-12s %s' % [data['id'], attr['name'], attr['owner'], attr['url']]
        end
      end
    end
  end
end

