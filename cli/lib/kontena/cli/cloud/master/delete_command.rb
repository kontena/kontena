module Kontena::Cli::Cloud::Master
  class DeleteCommand < Kontena::Command

    include Kontena::Cli::Common

    callback_matcher 'cloud-master', 'delete'

    requires_current_account_token

    parameter "MASTER_ID", "Master ID"

    option ['-f', '--force'], :flag, "Don't ask for confirmation"

    def execute
      confirm unless self.force?
      cloud_client.delete("user/masters/#{self.master_id}")
    end
  end
end

