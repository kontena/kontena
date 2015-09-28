module Kontena::Cli::Master::Vagrant
  class CreateCommand < Clamp::Command
    include Kontena::Cli::Common

    option "--memory", "MEMORY", "How much memory node has", default: '512'
    option "--version", "VERSION", "Define installed Kontena version", default: 'latest'

    def execute
      require 'kontena/machine/vagrant'
      provisioner = Kontena::Machine::Vagrant::MasterProvisioner.new
      provisioner.run!(
        memory: memory,
        version: version
      )
    end
  end
end
