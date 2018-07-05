
module Kontena::Cli::Certificate
  class DomainAuthorizeCommand < Kontena::Command
    subcommand ["rm", "remove"], "Remove domain authorization", load_subcommand('certificate/domain_authorization/remove_authorization_command')
    subcommand ["ls", "list"], "List domain authorizations", load_subcommand('certificate/domain_authorization/list_command')
  end
end