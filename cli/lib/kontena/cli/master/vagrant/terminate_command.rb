module Kontena::Cli::Master::Vagrant
  class TerminateCommand < Clamp::Command
    include Kontena::Cli::Common

    def execute
      require_api_url

      require 'kontena/machine/vagrant'
      destroyer = Kontena::Machine::Vagrant::MasterDestroyer.new(client(require_token))
      destroyer.run!
    end
  end
end
