module Kontena::Cli::Master::Vagrant
  class CreateCommand < Clamp::Command
    include Kontena::Cli::Common

    option "--memory", "MEMORY", "How much memory node has", default: '512'
    option "--version", "VERSION", "Define installed Kontena version", default: 'latest'
    option "--auth-server", "AUTH_SERVER", "Define authentication server url"

    def execute
      require 'kontena/machine/vagrant'
      provisioner = Kontena::Machine::Vagrant::MasterProvisioner.new
      provisioner.run!(
        memory: memory,
        version: version,
        auth_server: auth_server
      )
    end
  end
end
