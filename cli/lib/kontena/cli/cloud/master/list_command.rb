module Kontena::Cli::Cloud::Master
  class ListCommand < Kontena::Command

    include Kontena::Cli::Common
    include Kontena::Cli::TableGenerator::Helper

    callback_matcher 'cloud-master', 'list'

    option '--return', :flag, 'Return the list', hidden: true

    requires_current_account_token

    def fields
      quiet? ? ['id'] : %w(id name owner url connected)
    end

    def execute
      response = spin_if(!quiet?, "Retrieving Master list from Kontena Cloud") do
        cloud_client.get('user/masters')
      end

      unless response && response.kind_of?(Hash) && response['data'].kind_of?(Array)
        abort pastel.red("Listing masters failed")
      end

      return Array(response['data']) if self.return?

      print_table(response['data']) do |row|
        row.merge!(row['attributes'])
        row['connected'] = !!row['connected'] ? pastel.green('yes') : pastel.red('no')
      end
    end
  end
end

