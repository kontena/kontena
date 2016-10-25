module Kontena::Cli
  class RegisterCommand < Kontena::Command
    include Kontena::Cli::Common

    def execute
      exit_with_error "The register command has been removed in this version. Visit https://cloud.kontena.io/sign-up to create a Kontena Cloud account or use: kontena cloud login"
    end
  end
end
