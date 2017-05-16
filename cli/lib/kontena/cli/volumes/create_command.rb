
module Kontena::Cli::Volumes
  class CreateCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    banner "Creates a volume"
    parameter 'NAME', 'Volume name'

    SCOPES = %w(grid stack instance)

    option '--driver', 'DRIVER', 'Volume driver to be used', required: true
    option '--driver-opt', 'DRIVER_OPT', 'Volume driver options', multivalued: true
    option '--scope', 'SCOPE', "Volume scope (#{SCOPES.join(',')})", required: true do |scope|
      exit_with_error "Unknown scope '#{scope}, must be one of #{SCOPES.join(',')}" unless SCOPES.include?(scope)
      scope
    end

    requires_current_master
    requires_current_master_token

    def execute
      volume = {
        name: name,
        scope: scope,
        driver: driver,
        driver_opts: parse_driver_opts
      }
      spinner "Creating volume #{pastel.cyan(name)} " do
        create_volume(volume)
      end
    end

    def parse_driver_opts
      Hash[driver_opt_list.map{|opt| opt.split '='}]
    end

    def create_volume(volume)
      client.post("volumes/#{current_grid}", volume)
    end
  end
end
