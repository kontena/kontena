module Kontena
  module Callbacks
    class SuggestInvitingYourself < Kontena::Callback

      matches_commands 'master create'

      def after
        extend Kontena::Cli::Common

        return unless current_master
        return unless command.exit_code == 0
        return if current_master.username.to_s == 'admin'

        puts
        puts Kontena.pastel.green("Protip:")

        if config.find_server("#{current_master.name}-admin")
          puts "  You are currently using the Kontena Master '#{Kontena.pastel.yellow(current_master.name)}' as"
          puts "  #{Kontena.pastel.yellow(current_master.username)}. To switch to the Kontena Master internal"
          puts "  administrator you can use:"
          puts "  #{Kontena.pastel.green.on_black("  kontena master use #{current_master.name}-admin  ")}"
          puts
        end
        puts "  To invite more users you can use:"
        puts "  #{Kontena.pastel.green.on_black("  kontena master user invite email_address@example.com  ")}"
        puts
        puts "  The users can then join the master by using the invite code: "
        puts "  #{Kontena.pastel.green.on_black("  kontena master join #{current_master.url} <invite_code>  ")}"
        puts
      end
    end
  end
end
