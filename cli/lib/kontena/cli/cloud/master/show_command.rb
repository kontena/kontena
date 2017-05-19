module Kontena::Cli::Cloud::Master
  class ShowCommand < Kontena::Command

    include Kontena::Cli::Common

    callback_matcher 'cloud-master', 'show'

    requires_current_account_token

    parameter "CLOUD_MASTER_ID", "Master ID", attribute_name: :master_id

    def execute
      response = cloud_client.get("user/masters/#{master_id}")
      response['data']['attributes']['id'] = response['data']['id']
      response['data']['attributes'].each do |key, value|
        puts "%20.20s : %s" % [key, value]
      end
    end
  end
end

