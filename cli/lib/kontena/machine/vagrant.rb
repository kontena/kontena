require_relative 'common'
include Kontena::Machine::Common

unless which('vagrant')
  abort('Vagrant is not installed. See https://www.vagrantup.com/ for instructions.')
end

require_relative 'random_name'
require_relative 'vagrant/master_provisioner'
require_relative 'vagrant/node_provisioner'
require_relative 'vagrant/node_destroyer'
