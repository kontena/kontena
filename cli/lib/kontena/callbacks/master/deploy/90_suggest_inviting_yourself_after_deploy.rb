module Kontena
  module Callbacks
    class SuggestInvitingYourself < Kontena::Callback

      include Kontena::Cli::Common

      matches_commands 'master create'

      def after
        return unless current_master
        return unless command.exit_code == 0
        return unless current_master.username.to_s == 'admin'

        puts
        puts "Protip:"
        puts "  You are currently using Kontena Master administrator account."
        puts "  Consider inviting yourself as a regular user. Use: "
        puts "    kontena master users invite -r master_admin your@email.address.example.com"
        puts "    kontena master join <master_url> <invite_code>"
        puts
      end
    end
  end
end
