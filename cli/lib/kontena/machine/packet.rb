begin
  gem 'packethost', '>= 0.0.6'
  require 'packethost'
rescue LoadError
  puts "It seems that you don't have Packet API installed."
  puts "Install it using: gem install packethost"
  exit 1
end

require_relative 'random_name'
require_relative 'cert_helper'
require_relative 'packet/packet_common'
require_relative 'packet/node_provisioner'
require_relative 'packet/node_destroyer'
require_relative 'packet/node_restarter'
require_relative 'packet/master_provisioner'

