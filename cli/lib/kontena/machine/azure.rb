begin
  require "azure"
rescue LoadError
  puts "It seems that you don't have Azure SDK installed."
  puts "Install it using: gem install azure:0.7.0"
  exit 1
end

require_relative 'random_name'
require_relative 'azure/logger'
require_relative 'azure/node_provisioner'
require_relative 'azure/node_destroyer'
