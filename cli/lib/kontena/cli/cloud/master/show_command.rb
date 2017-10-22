module Kontena::Cli::Cloud::Master
  class ShowCommand < Kontena::Command

    callback_matcher 'cloud-master', 'show'

    requires_current_account_token

    parameter "MASTER_ID", "Master ID"

    def execute
      response = cloud_client.get("user/masters/#{master_id}")
      response['data']['attributes']['id'] = response['data']['id']
      response['data']['attributes'].each do |key, value|
        puts "%20.20s : %s" % [key, value]
      end
    end
  end
end

