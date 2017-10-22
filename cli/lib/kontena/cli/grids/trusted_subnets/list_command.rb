require 'kontena/cli/grids/common'

module Kontena::Cli::Grids::TrustedSubnets
  class ListCommand < Kontena::Command
    include Kontena::Cli::GridOptions
    include Kontena::Cli::Grids::Common

    # the command outputs id info only anyway, this is here strictly for ignoring purposes
    option ['-q', '--quiet'], :flag, "Output the identifying column only", hidden: true

    requires_current_master

    def execute
      Array(get_grid['trusted_subnets']).map(&method(:puts))
    end
  end
end
