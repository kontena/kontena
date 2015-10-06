begin
  require "fog/aws"
rescue LoadError
  puts "It seems that you don't have gem for AWS API installed."
  puts "Install it using: gem install fog-aws"
  exit 1
end

require_relative 'random_name'
require_relative 'aws/node_provisioner'
require_relative 'aws/node_destroyer'

