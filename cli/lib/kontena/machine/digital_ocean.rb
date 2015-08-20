begin
  require "droplet_kit"
rescue LoadError
  puts "It seems that you don't have Digital Ocean API installed."
  puts "Install it using: gem install droplet_kit"
  exit 1
end

require_relative 'random_name'
require_relative 'digital_ocean/node_provisioner'
require_relative 'digital_ocean/node_destroyer'
